use super::*;

/// Byte accesses into a Workgroup array of 32-bit words: `PtrAccessChain %byte_ptr = %word_ptr, %k` whose result points
/// at an 8-bit integer while `%word_ptr` (an access chain ending in an array index) points at a 32-bit unsigned word, used
/// only by Stores and Loads of the 8-bit type.
///
/// The emitter writes this for an LLVM `getelementptr i8` off a workgroup word (gep_provenance's byte view), which
/// Vulkan cannot express: a Workgroup pointer cannot change its pointee type. Each Store becomes a read-modify-write of
/// the word the byte is in (word index = the array index + k / 4, bits (k % 4) * 8), and each Load a shift and
/// truncation of that word. WebKit zero-initialises every WGSL `var<workgroup>` this way (`__wgslZeroWorkgroupVar`
/// stores 0 byte by byte, from one invocation, before a barrier); WAS: a later pass rewrote the byte view as a pointer to
/// the word and the 8-bit Store broke the Store contract, so every WGSL compute shader with a workgroup variable was
/// refused (Safari, tools/regress/pages/sweep.html, 11 Nov 2026).
///
/// The read-modify-write is not atomic: two invocations writing different bytes of one word at the same time can lose
/// one write. Metal gives no such guarantee either for non-atomic byte stores racing on one word, and the shaders seen
/// (WebKit's zeroing) write from one invocation.
pub(in crate::passes) fn lower_workgroup_word_byte_views(ctx: &mut Ctx, function_idx: usize) {
    let mut ptr_info: HashMap<Word, (StorageClass, Word)> = HashMap::default();
    let mut type_defs: HashMap<Word, Instruction> = HashMap::default();
    for inst in ctx.new_globals.iter().chain(ctx.module.types_global_values.iter()) {
        if let Some(id) = inst.result_id {
            type_defs.insert(id, inst.clone());
        }
        if inst.class.opcode == Op::TypePointer {
            if let (Some(id), Some(Operand::StorageClass(s)), Some(Operand::IdRef(p))) =
                (inst.result_id, inst.operands.first(), inst.operands.get(1))
            {
                ptr_info.insert(id, (*s, *p));
            }
        }
    }
    let int_width = |ty: Word| -> Option<(u32, u32)> {
        let d = type_defs.get(&ty)?;
        match (d.class.opcode, d.operands.first(), d.operands.get(1)) {
            (Op::TypeInt, Some(Operand::LiteralBit32(w)), Some(Operand::LiteralBit32(s))) => Some((*w, *s)),
            _ => None,
        }
    };
    let value_types = function_value_types(ctx, function_idx);
    let defs: HashMap<Word, Instruction> = ctx.module.functions[function_idx]
        .blocks
        .iter()
        .flat_map(|b| &b.instructions)
        .filter_map(|i| Some((i.result_id?, i.clone())))
        .collect();
    let mut users: HashMap<Word, Vec<Op>> = HashMap::default();
    for inst in ctx.module.functions[function_idx].blocks.iter().flat_map(|b| &b.instructions) {
        for (k, op) in inst.operands.iter().enumerate() {
            if let Operand::IdRef(id) = op {
                // a Store's pointer is operand 0; as the stored object (operand 1) the byte pointer escapes
                let role = if inst.class.opcode == Op::Store && k == 1 { Op::Nop } else { inst.class.opcode };
                users.entry(*id).or_default().push(role);
            }
        }
    }
    // the element type an access chain's last index selects inside, and the operands before that index
    let array_element_of_chain = |chain: &Instruction| -> Option<Word> {
        if !matches!(chain.class.opcode, Op::AccessChain | Op::InBoundsAccessChain) || chain.operands.len() < 2 {
            return None;
        }
        let Operand::IdRef(root) = chain.operands[0] else { return None };
        let root_ty = value_types.get(&root)?;
        let &(storage, mut cur) = ptr_info.get(root_ty)?;
        if storage != StorageClass::Workgroup {
            return None;
        }
        let last = chain.operands.len() - 1;
        for op in &chain.operands[1..last] {
            let Operand::IdRef(index) = op else { return None };
            let d = type_defs.get(&cur)?;
            cur = match d.class.opcode {
                Op::TypeArray | Op::TypeRuntimeArray => match d.operands.first() {
                    Some(Operand::IdRef(e)) => *e,
                    _ => return None,
                },
                Op::TypeStruct => {
                    let member = const_u32(ctx, *index)? as usize;
                    match d.operands.get(member) {
                        Some(Operand::IdRef(m)) => *m,
                        _ => return None,
                    }
                }
                _ => return None,
            };
        }
        let d = type_defs.get(&cur)?;
        if !matches!(d.class.opcode, Op::TypeArray | Op::TypeRuntimeArray) {
            return None;
        }
        match d.operands.first() {
            Some(Operand::IdRef(e)) => Some(*e),
            _ => None,
        }
    };

    struct View {
        chain: Instruction,
        byte_ty: Word,
        k: Word,
        k_bits: u32,
    }
    let mut views: HashMap<Word, View> = HashMap::default();
    for inst in ctx.module.functions[function_idx].blocks.iter().flat_map(|b| &b.instructions) {
        if inst.class.opcode != Op::PtrAccessChain || inst.operands.len() != 2 {
            continue;
        }
        let (Some(rp), Some(rpt)) = (inst.result_id, inst.result_type) else { continue };
        let Some(&(StorageClass::Workgroup, byte_ty)) = ptr_info.get(&rpt) else { continue };
        if int_width(byte_ty).map(|(w, _)| w) != Some(8) {
            continue;
        }
        let (Operand::IdRef(base), Operand::IdRef(k)) = (&inst.operands[0], &inst.operands[1]) else { continue };
        let Some(base_ty) = value_types.get(base) else { continue };
        let Some(&(StorageClass::Workgroup, word_ty)) = ptr_info.get(base_ty) else { continue };
        if int_width(word_ty) != Some((32, 0)) {
            continue;
        }
        let Some(chain) = defs.get(base) else { continue };
        if array_element_of_chain(chain) != Some(word_ty) {
            continue;
        }
        let Some(k_bits) = value_types.get(k).and_then(|t| int_width(*t)).map(|(w, _)| w) else { continue };
        if !matches!(k_bits, 32 | 64) {
            continue;
        }
        // the byte pointer is only loaded from and stored through
        let ok = users.get(&rp).is_some_and(|u| u.iter().all(|op| matches!(op, Op::Load | Op::Store)));
        if !ok {
            continue;
        }
        views.insert(rp, View { chain: chain.clone(), byte_ty, k: *k, k_bits });
    }
    if views.is_empty() {
        return;
    }
    let uint = ctx.ty_uint();
    let word_ptr_ty = ctx.ty_ptr(StorageClass::Workgroup, uint);
    let c2 = ctx.const_uint(2);
    let c3 = ctx.const_uint(3);
    let cff = ctx.const_uint(0xff);

    let n_blocks = ctx.module.functions[function_idx].blocks.len();
    for bi in 0..n_blocks {
        let insts = std::mem::take(&mut ctx.module.functions[function_idx].blocks[bi].instructions);
        let mut out: Vec<Instruction> = Vec::with_capacity(insts.len() + 16);
        for inst in insts {
            // the byte view itself goes; each use computes its word pointer and bit offset
            if inst.class.opcode == Op::PtrAccessChain && inst.result_id.is_some_and(|r| views.contains_key(&r)) {
                continue;
            }
            let ptr = match (inst.class.opcode, inst.operands.first()) {
                (Op::Load | Op::Store, Some(Operand::IdRef(p))) if views.contains_key(p) => *p,
                _ => {
                    out.push(inst);
                    continue;
                }
            };
            let v = &views[&ptr];
            let mut emit = |out: &mut Vec<Instruction>, op: Op, ty: Word, operands: Vec<Word>| -> Word {
                let id = ctx.module.fresh_id();
                out.push(Instruction::new(op, Some(ty), Some(id), operands.into_iter().map(Operand::IdRef).collect()));
                id
            };
            let k32 = if v.k_bits == 32 { v.k } else { emit(&mut out, Op::UConvert, uint, vec![v.k]) };
            let word_k = emit(&mut out, Op::ShiftRightLogical, uint, vec![k32, c2]);
            let Operand::IdRef(last) = v.chain.operands[v.chain.operands.len() - 1] else { unreachable!() };
            let last_bits = value_types.get(&last).and_then(|t| int_width(*t)).map(|(w, _)| w).unwrap_or(32);
            let last32 = if last_bits == 32 { last } else { emit(&mut out, Op::UConvert, uint, vec![last]) };
            let index = emit(&mut out, Op::IAdd, uint, vec![last32, word_k]);
            let mut chain_ops: Vec<Word> = v.chain.operands[..v.chain.operands.len() - 1]
                .iter()
                .filter_map(|o| if let Operand::IdRef(id) = o { Some(*id) } else { None })
                .collect();
            chain_ops.push(index);
            let word_ptr = emit(&mut out, v.chain.class.opcode, word_ptr_ty, chain_ops);
            let lane = emit(&mut out, Op::BitwiseAnd, uint, vec![k32, c3]);
            let shift = emit(&mut out, Op::ShiftLeftLogical, uint, vec![lane, c3]);
            if inst.class.opcode == Op::Load {
                let word = emit(&mut out, Op::Load, uint, vec![word_ptr]);
                let moved = emit(&mut out, Op::ShiftRightLogical, uint, vec![word, shift]);
                let Some(result) = inst.result_id else { continue };
                out.push(Instruction::new(Op::UConvert, Some(v.byte_ty), Some(result), vec![Operand::IdRef(moved)]));
            } else {
                let Some(Operand::IdRef(value)) = inst.operands.get(1).cloned() else { continue };
                let wide = emit(&mut out, Op::UConvert, uint, vec![value]);
                let placed = emit(&mut out, Op::ShiftLeftLogical, uint, vec![wide, shift]);
                let mask = emit(&mut out, Op::ShiftLeftLogical, uint, vec![cff, shift]);
                let keep = emit(&mut out, Op::Not, uint, vec![mask]);
                let word = emit(&mut out, Op::Load, uint, vec![word_ptr]);
                let kept = emit(&mut out, Op::BitwiseAnd, uint, vec![word, keep]);
                let merged = emit(&mut out, Op::BitwiseOr, uint, vec![kept, placed]);
                out.push(Instruction::new(Op::Store, None, None, vec![Operand::IdRef(word_ptr), Operand::IdRef(merged)]));
            }
        }
        ctx.module.functions[function_idx].blocks[bi].instructions = out;
    }
}
