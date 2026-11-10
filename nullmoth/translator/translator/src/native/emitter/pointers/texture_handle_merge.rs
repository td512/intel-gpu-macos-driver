//! Texture handles merged by a `phi` or `select` (`%t = phi ptr addrspace(1) [ %a, %bb1 ], [ %b, %bb2 ]` feeding an AIR
//! texture operation).
//!
//! Each argument-buffer texture the emitter reads under bindless-all is a fact, not a value: the handle's id is left for
//! the passes, which replace its use with `heap[slot]` (`buffer_pointer_heap_loads` for a bound argument buffer,
//! `device_handle_heap_loads` for one reached through a device address). A merged handle had no fact of its own, so
//! the texture operation found no texture: it fell back to whatever image the entry had bound (or, with none, read
//! zero). SPIR-V's logical addressing does not let a pointer to a descriptor be merged, but an index into the heap
//! is a plain integer: the merge becomes an `OpPhi`/`OpSelect` of the incoming heap slots, and the merged handle a fact
//! with that slot. The slots of the incoming values are computed where those values are loaded, so they dominate the
//! predecessor edges (phi) or the select itself.
//!
//! A merge whose incoming values are not all heap-slot facts of the same kind (a back-edge value not emitted yet, a
//! texture bound directly, a null handle) is left to the general pointer paths, as before.
use super::*;

enum MergedSlots {
    /// slots of handles read from a bound argument buffer: (root, byte offset, slot) per incoming value
    Buffer(Vec<(Word, u64, Word)>),
    /// slots of handles read through a device address
    Device(Vec<Word>),
}

impl Emitter {
    fn texture_handle_merge_slots(&self, name: &str, values: &[&LlValue]) -> Option<MergedSlots> {
        if !crate::reflect::bindless_fixed_fields_on() || !self.opaque_resource_pointers.contains(name) {
            return None;
        }
        let ids = values
            .iter()
            .map(|value| match value {
                LlValue::Local(local) => self.values.get(local).map(|(id, _)| *id),
                _ => None,
            })
            .collect::<Option<Vec<_>>>()?;
        let buffer = ids
            .iter()
            .map(|id| {
                self.emit_sidecar
                    .buffer_pointer_heap_loads
                    .iter()
                    .find(|fact| fact.id == *id)
                    .map(|fact| (fact.root, fact.byte_offset, fact.slot))
            })
            .collect::<Option<Vec<_>>>();
        if let Some(buffer) = buffer {
            return Some(MergedSlots::Buffer(buffer));
        }
        let device = ids
            .iter()
            .map(|id| {
                self.emit_sidecar
                    .device_handle_heap_loads
                    .iter()
                    .find(|fact| fact.id == *id && !fact.sampler)
                    .map(|fact| fact.slot)
            })
            .collect::<Option<Vec<_>>>()?;
        Some(MergedSlots::Device(device))
    }

    fn record_merged_texture_handle(&mut self, result: Word, slots: &MergedSlots, slot: Word) {
        match slots {
            // one fact per incoming field, all with the merged slot: whichever field the passes route through the
            // heap, the merged handle reads `heap[slot]`
            MergedSlots::Buffer(fields) => {
                for &(root, byte_offset, _) in fields {
                    let fact = crate::emit_sidecar::BufferPointerHeapLoad {
                        id: result,
                        root,
                        byte_offset,
                        slot,
                    };
                    if !self.emit_sidecar.buffer_pointer_heap_loads.contains(&fact) {
                        self.emit_sidecar.buffer_pointer_heap_loads.push(fact);
                    }
                }
            }
            MergedSlots::Device(_) => {
                self.emit_sidecar.device_handle_heap_loads.push(
                    crate::emit_sidecar::DeviceHandleHeapLoad {
                        id: result,
                        slot,
                        sampler: false,
                    },
                );
            }
        }
    }

    fn merged_slot_ids(slots: &MergedSlots) -> Vec<Word> {
        match slots {
            MergedSlots::Buffer(fields) => fields.iter().map(|&(_, _, slot)| slot).collect(),
            MergedSlots::Device(slots) => slots.clone(),
        }
    }

    /// `phi` of argument-buffer texture handles: an `OpPhi` of their heap slots. False when the merge is not one.
    pub(in crate::native::emitter) fn emit_texture_handle_phi(
        &mut self,
        name: &str,
        incoming: &[(LlValue, String)],
        result_ty: &LlType,
        instructions: &mut Vec<Instruction>,
    ) -> Result<bool, String> {
        if !matches!(result_ty, LlType::Ptr(1)) || incoming.is_empty() {
            return Ok(false);
        }
        let values = incoming.iter().map(|(value, _)| value).collect::<Vec<_>>();
        let Some(slots) = self.texture_handle_merge_slots(name, &values) else {
            return Ok(false);
        };
        let slot_ids = Self::merged_slot_ids(&slots);
        let mut ops = Vec::new();
        let mut seen: HashMap<Word, Word> = HashMap::default();
        for ((_, label), slot) in incoming.iter().zip(slot_ids) {
            let label_id = self.label_id(label)?;
            if let Some(existing) = seen.insert(label_id, slot) {
                if existing != slot {
                    return Ok(false);
                }
                continue;
            }
            ops.push(Operand::IdRef(slot));
            ops.push(Operand::IdRef(label_id));
        }
        self.emit_pointer_nullness_phi(name, incoming, result_ty, instructions)?;
        let u32_ty = self.type_id(&LlType::Int(32))?;
        let slot = self.fresh();
        instructions.push(Self::inst(Op::Phi, Some(u32_ty), Some(slot), ops));
        let result = self.result_id(name, result_ty)?;
        self.record_merged_texture_handle(result, &slots, slot);
        Ok(true)
    }

    /// `select` of argument-buffer texture handles: an `OpSelect` of their heap slots. False when it is not one.
    pub(in crate::native::emitter) fn emit_texture_handle_select(
        &mut self,
        name: &str,
        cond: Word,
        true_value: &LlValue,
        false_value: &LlValue,
        result_ty: &LlType,
        instructions: &mut Vec<Instruction>,
    ) -> Result<bool, String> {
        if !matches!(result_ty, LlType::Ptr(1)) {
            return Ok(false);
        }
        let Some(slots) = self.texture_handle_merge_slots(name, &[true_value, false_value]) else {
            return Ok(false);
        };
        let [on_true, on_false] = Self::merged_slot_ids(&slots)[..] else {
            return Ok(false);
        };
        let null_true = self.pointer_nullness_phi_value_id(true_value)?;
        let null_false = self.pointer_nullness_phi_value_id(false_value)?;
        let bool_ty = self.type_id(&LlType::Bool)?;
        let is_null = self.fresh();
        instructions.push(Self::inst(
            Op::Select,
            Some(bool_ty),
            Some(is_null),
            vec![
                Operand::IdRef(cond),
                Operand::IdRef(null_true),
                Operand::IdRef(null_false),
            ],
        ));
        self.record_pointer_nullness(name.to_string(), is_null);
        let u32_ty = self.type_id(&LlType::Int(32))?;
        let slot = self.fresh();
        instructions.push(Self::inst(
            Op::Select,
            Some(u32_ty),
            Some(slot),
            vec![
                Operand::IdRef(cond),
                Operand::IdRef(on_true),
                Operand::IdRef(on_false),
            ],
        ));
        let result = self.result_id(name, result_ty)?;
        self.record_merged_texture_handle(result, &slots, slot);
        Ok(true)
    }
}
