use crate::fxhash::{HashMap, HashSet};
use crate::spirv_module::Operand;
use crate::spirv_module::{load_bytes, Module};
use spirv::{Decoration, Op, StorageClass, Word};

mod bounded_work;
mod buffers;
mod byte_image;
mod control_flow;
mod interface;
mod intrinsics;
mod misc;
mod textures;
mod threadgroup;
mod types;

fn asm_has_line(asm: &str, needle: &str) -> bool {
    asm.lines().any(|line| line.trim() == needle)
}

fn whole_workgroup_options() -> crate::passes::TransformOptions {
    crate::passes::TransformOptions {
        kernel_dispatch: Some(crate::reflect::KernelDispatch::Workgroups),
        ..crate::passes::TransformOptions::default()
    }
}

fn assert_no_pointer_bitcasts(spv: &[u8]) {
    let module = load_bytes(spv).expect("load spv");
    let pointer_types = module
        .types_global_values
        .iter()
        .filter_map(|inst| {
            (inst.class.opcode == Op::TypePointer)
                .then_some(inst.result_id)
                .flatten()
        })
        .collect::<HashSet<_>>();
    let pointer_bitcast = module.all_inst_iter().find(|inst| {
        inst.class.opcode == Op::Bitcast
            && inst
                .result_type
                .is_some_and(|ty| pointer_types.contains(&ty))
    });
    assert!(pointer_bitcast.is_none(), "{pointer_bitcast:?}");
}

fn uint32_type_id(asm: &str) -> String {
    asm.lines()
        .find(|line| line.trim_end().ends_with("OpTypeInt 32 0"))
        .and_then(|line| line.split_whitespace().next())
        .unwrap_or("%uint")
        .to_string()
}

fn interface_variable_at_location(
    module: &Module,
    storage: StorageClass,
    location: u32,
) -> Option<Word> {
    module.annotations.iter().find_map(|inst| {
        if inst.class.opcode != Op::Decorate {
            return None;
        }
        let [
            Operand::IdRef(id),
            Operand::Decoration(Decoration::Location),
            Operand::LiteralBit32(loc),
        ] = inst.operands.as_slice()
        else {
            return None;
        };
        if *loc != location || variable_storage_class(module, *id) != Some(storage) {
            return None;
        }
        Some(*id)
    })
}

fn variable_storage_class(module: &Module, var: Word) -> Option<StorageClass> {
    module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::Variable && inst.result_id == Some(var) {
            if let Some(Operand::StorageClass(storage)) = inst.operands.first() {
                return Some(*storage);
            }
        }
        None
    })
}

fn pointer_type_storage_class(module: &Module, ptr_ty: Word) -> Option<StorageClass> {
    module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::TypePointer && inst.result_id == Some(ptr_ty) {
            if let Some(Operand::StorageClass(storage)) = inst.operands.first() {
                return Some(*storage);
            }
        }
        None
    })
}

fn variable_pointee_type(module: &Module, var: Word) -> Option<Word> {
    let ptr_ty = module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::Variable && inst.result_id == Some(var) {
            inst.result_type
        } else {
            None
        }
    })?;
    module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::TypePointer && inst.result_id == Some(ptr_ty) {
            if let Some(Operand::IdRef(pointee)) = inst.operands.get(1) {
                return Some(*pointee);
            }
        }
        None
    })
}

fn assert_phi_operand_types_match(module: &Module, asm: &str) {
    let result_types = module
        .all_inst_iter()
        .filter_map(|inst| Some((inst.result_id?, inst.result_type?)))
        .collect::<HashMap<_, _>>();
    for inst in module.all_inst_iter() {
        if inst.class.opcode != Op::Phi {
            continue;
        }
        let Some(result_type) = inst.result_type else {
            continue;
        };
        for incoming in inst.operands.chunks(2) {
            let [Operand::IdRef(value), Operand::IdRef(_label)] = incoming else {
                continue;
            };
            assert_eq!(
                result_types.get(value),
                Some(&result_type),
                "phi {:?} incoming value {value} has mismatched type\n{asm}",
                inst.result_id
            );
        }
    }
}

fn is_unsigned_int_vector(module: &Module, ty: Word, bits: u32, lanes: u32) -> bool {
    let Some(elem) = module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::TypeVector
            && inst.result_id == Some(ty)
            && inst.operands.get(1) == Some(&Operand::LiteralBit32(lanes))
        {
            if let Some(Operand::IdRef(elem)) = inst.operands.first() {
                return Some(*elem);
            }
        }
        None
    }) else {
        return false;
    };
    module.types_global_values.iter().any(|inst| {
        inst.class.opcode == Op::TypeInt
            && inst.result_id == Some(elem)
            && inst.operands.first() == Some(&Operand::LiteralBit32(bits))
            && inst.operands.get(1) == Some(&Operand::LiteralBit32(0))
    })
}

fn is_float_vector(module: &Module, ty: Word, lanes: u32) -> bool {
    let Some(elem) = module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::TypeVector
            && inst.result_id == Some(ty)
            && inst.operands.get(1) == Some(&Operand::LiteralBit32(lanes))
        {
            if let Some(Operand::IdRef(elem)) = inst.operands.first() {
                return Some(*elem);
            }
        }
        None
    }) else {
        return false;
    };
    module.types_global_values.iter().any(|inst| {
        inst.class.opcode == Op::TypeFloat
            && inst.result_id == Some(elem)
            && inst.operands.first() == Some(&Operand::LiteralBit32(32))
    })
}

fn is_signed_i32_vector(module: &Module, ty: Word, lanes: u32) -> bool {
    let Some(elem) = module.types_global_values.iter().find_map(|inst| {
        if inst.class.opcode == Op::TypeVector
            && inst.result_id == Some(ty)
            && inst.operands.get(1) == Some(&Operand::LiteralBit32(lanes))
        {
            if let Some(Operand::IdRef(elem)) = inst.operands.first() {
                return Some(*elem);
            }
        }
        None
    }) else {
        return false;
    };
    module.types_global_values.iter().any(|inst| {
        inst.class.opcode == Op::TypeInt
            && inst.result_id == Some(elem)
            && inst.operands.first() == Some(&Operand::LiteralBit32(32))
            && inst.operands.get(1) == Some(&Operand::LiteralBit32(1))
    })
}

fn decorated(module: &Module, target: Word, decoration: Decoration, value: u32) -> bool {
    module.annotations.iter().any(|inst| {
        inst.class.opcode == Op::Decorate
            && inst.operands.first() == Some(&Operand::IdRef(target))
            && inst.operands.get(1) == Some(&Operand::Decoration(decoration))
            && inst.operands.get(2) == Some(&Operand::LiteralBit32(value))
    })
}

fn variables_at(module: &Module, set: u32, binding: u32) -> HashSet<Word> {
    module
        .types_global_values
        .iter()
        .filter(|inst| inst.class.opcode == Op::Variable)
        .filter_map(|inst| inst.result_id)
        .filter(|var| {
            decorated(module, *var, Decoration::DescriptorSet, set)
                && decorated(module, *var, Decoration::Binding, binding)
        })
        .collect()
}

/// Under bindless-all (the default; NVMTL_NO_BINDLESS_ALL=1 turns it off) a sampled texture whose Metal index is below
/// 128 has no descriptor binding of its own: the shader reads its heap slot from word TEXTURE_INDEX_BASE (64) + index
/// of the per-draw table (set 0, binding SYNTHETIC_BINDING_BASE) and indexes the sampled-image heap (set
/// BINDLESS_HEAP_SET, binding BINDLESS_HEAP_BINDING) with it (passes::resources::collapse, ParamBinding::HeapImage).
/// Returns the dimension of the image the shader loads that way for `metal_index`, or None when it does not.
fn heap_texture_dim(spv: &[u8], metal_index: u32) -> Option<spirv::Dim> {
    const TEXTURE_INDEX_BASE: u32 = 64;
    let module = load_bytes(spv).expect("load translated module");
    let tables = variables_at(&module, 0, crate::reflect::SYNTHETIC_BINDING_BASE);
    let heaps = variables_at(
        &module,
        crate::reflect::BINDLESS_HEAP_SET,
        crate::reflect::BINDLESS_HEAP_BINDING,
    );
    let slot_words = module
        .types_global_values
        .iter()
        .filter(|inst| {
            inst.class.opcode == Op::Constant
                && inst.operands.first()
                    == Some(&Operand::LiteralBit32(TEXTURE_INDEX_BASE + metal_index))
        })
        .filter_map(|inst| inst.result_id)
        .collect::<HashSet<_>>();
    let id_at = |inst: &crate::spirv_module::Instruction, at: usize| match inst.operands.get(at) {
        Some(Operand::IdRef(id)) => Some(*id),
        _ => None,
    };
    let mut slot_pointers = HashSet::default();
    let mut slots = HashSet::default();
    let mut heap = None;
    for inst in module.all_inst_iter() {
        let (Some(result), Some(first)) = (inst.result_id, id_at(inst, 0)) else {
            continue;
        };
        match inst.class.opcode {
            Op::AccessChain
                if tables.contains(&first)
                    && inst.operands.iter().skip(1).any(
                        |operand| matches!(operand, Operand::IdRef(id) if slot_words.contains(id)),
                    ) =>
            {
                slot_pointers.insert(result);
            }
            Op::Load if slot_pointers.contains(&first) => {
                slots.insert(result);
            }
            Op::UConvert | Op::BitwiseAnd if slots.contains(&first) => {
                slots.insert(result);
            }
            Op::AccessChain
                if heaps.contains(&first) && id_at(inst, 1).is_some_and(|slot| slots.contains(&slot)) =>
            {
                heap = Some(first);
            }
            _ => {}
        }
    }
    let array = variable_pointee_type(&module, heap?)?;
    let def = |id: Word| {
        module
            .types_global_values
            .iter()
            .find(|inst| inst.result_id == Some(id))
    };
    let image = match def(array)?.operands.first() {
        Some(Operand::IdRef(element)) => def(*element)?,
        _ => return None,
    };
    match (image.class.opcode, image.operands.get(1)) {
        (Op::TypeImage, Some(Operand::Dim(dim))) => Some(*dim),
        _ => None,
    }
}

/// A device-address load is a call of a helper the emitter keeps out of line (emit_device_addr_load,
/// null_bda_load_helper): `helper(base, address)` loads `address` unless `base` is null, and returns zero then.
/// The helpers of `module`, by function id.
fn null_bda_load_helpers(module: &Module) -> HashSet<Word> {
    module
        .functions
        .iter()
        .filter(|function| {
            let [entry, live, merge] = &function.blocks[..] else {
                return false;
            };
            let [base, address] = &function.parameters[..] else {
                return false;
            };
            let uses = |inst: &crate::spirv_module::Instruction, id: Option<Word>| {
                id.is_some_and(|id| inst.operands.first() == Some(&Operand::IdRef(id)))
            };
            entry
                .instructions
                .iter()
                .any(|inst| inst.class.opcode == Op::INotEqual && uses(inst, base.result_id))
                && live
                    .instructions
                    .iter()
                    .any(|inst| inst.class.opcode == Op::ConvertUToPtr && uses(inst, address.result_id))
                && live.instructions.iter().any(|inst| inst.class.opcode == Op::Load)
                && merge.instructions.iter().any(|inst| inst.class.opcode == Op::Phi)
        })
        .filter_map(|function| function.def.as_ref()?.result_id)
        .collect()
}

/// The values `module` reads through a null-guarded device-address load helper, with the address each one reads.
fn null_bda_loads(module: &Module) -> HashMap<Word, Word> {
    let helpers = null_bda_load_helpers(module);
    module
        .all_inst_iter()
        .filter(|inst| inst.class.opcode == Op::FunctionCall)
        .filter_map(|inst| match inst.operands[..] {
            [Operand::IdRef(helper), Operand::IdRef(_), Operand::IdRef(address)]
                if helpers.contains(&helper) =>
            {
                Some((inst.result_id?, address))
            }
            _ => None,
        })
        .collect()
}
