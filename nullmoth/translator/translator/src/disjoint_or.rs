//! An `or` whose operands share no set bit is an add. LLVM's instcombine writes `a + c` as `or a, c` whenever it can
//! prove that (AIR is optimized that way: `As[kk][ty * 4 + i]` reaches the translator as `or (shl ty, 2), i`), and
//! Mesa's load/store vectorizer follows only iadd chains when it looks for neighbouring offsets. Every such index kept
//! four neighbouring loads apart: clbench's sgemm_reg issued 128 scalar SLM loads per K tile on the B580 instead of
//! 32 four-wide ones (IGC on Windows: 32), and its C stores stayed scalar. This pass rewrites OpBitwiseOr to OpIAdd
//! when one operand is an integer constant c and the other has at least bit_length(c) known trailing zero bits, which
//! is exactly the case where `x | c == x + c` (no carry can occur). Nothing else changes.
use crate::fxhash::HashMap;
use crate::spirv_module::{Instruction, Module, Operand};
use spirv::{Op, Word};

fn id_of(o: Option<&Operand>) -> Option<Word> {
    match o {
        Some(Operand::IdRef(v)) => Some(*v),
        _ => None,
    }
}

fn int_constants(module: &Module) -> HashMap<Word, u64> {
    let ints: HashMap<Word, ()> = module
        .types_global_values
        .iter()
        .filter(|i| i.class.opcode == Op::TypeInt)
        .filter_map(|i| i.result_id.map(|r| (r, ())))
        .collect();
    module
        .types_global_values
        .iter()
        .filter(|i| i.class.opcode == Op::Constant && i.result_type.is_some_and(|t| ints.contains_key(&t)))
        .filter_map(|i| {
            let v = match i.operands.first()? {
                Operand::LiteralBit32(v) => *v as u64,
                Operand::LiteralBit64(v) => *v,
                _ => return None,
            };
            Some((i.result_id?, v))
        })
        .collect()
}

/// Known trailing zero bits of `id` (a lower bound; 0 = nothing known). Depth-limited.
fn trailing_zeros(
    id: Word,
    defs: &HashMap<Word, &Instruction>,
    consts: &HashMap<Word, u64>,
    memo: &mut HashMap<Word, u32>,
    depth: u32,
) -> u32 {
    if let Some(c) = consts.get(&id) {
        return if *c == 0 { 64 } else { c.trailing_zeros() };
    }
    if let Some(k) = memo.get(&id) {
        return *k;
    }
    if depth == 0 {
        return 0;
    }
    let Some(i) = defs.get(&id) else { return 0 };
    let tz = |o: usize, memo: &mut HashMap<Word, u32>| {
        id_of(i.operands.get(o)).map_or(0, |x| trailing_zeros(x, defs, consts, memo, depth - 1))
    };
    let k = match i.class.opcode {
        Op::ShiftLeftLogical => match id_of(i.operands.get(1)).and_then(|s| consts.get(&s)) {
            Some(s) if *s < 64 => (tz(0, memo) + *s as u32).min(64),
            _ => tz(0, memo),
        },
        Op::IMul => (tz(0, memo) + tz(1, memo)).min(64),
        Op::IAdd | Op::ISub | Op::BitwiseOr | Op::BitwiseXor => tz(0, memo).min(tz(1, memo)),
        Op::BitwiseAnd => tz(0, memo).max(tz(1, memo)),
        Op::UConvert | Op::SConvert | Op::Bitcast | Op::CopyObject => tz(0, memo),
        // (value, block) pairs. 0 is recorded first, so a phi met again on a loop path counts as unknown: sound.
        Op::Phi => {
            memo.insert(id, 0);
            (0..i.operands.len()).step_by(2).map(|o| tz(o, memo)).min().unwrap_or(0)
        }
        _ => 0,
    };
    memo.insert(id, k);
    k
}

/// Returns how many OpBitwiseOr became OpIAdd.
pub(crate) fn disjoint_or_to_iadd_module(module: &mut Module) -> usize {
    let consts = int_constants(module);
    let mut rewritten = Vec::new();
    for (fi, f) in module.functions.iter().enumerate() {
        let defs: HashMap<Word, &Instruction> =
            f.all_inst_iter().filter_map(|i| i.result_id.map(|r| (r, i))).collect();
        let mut memo = HashMap::default();
        for (bi, b) in f.blocks.iter().enumerate() {
            for (ii, i) in b.instructions.iter().enumerate() {
                if i.class.opcode != Op::BitwiseOr {
                    continue;
                }
                let (Some(x), Some(y)) = (id_of(i.operands.first()), id_of(i.operands.get(1))) else { continue };
                let fits = |v: Word, c: Word, memo: &mut HashMap<Word, u32>| {
                    consts.get(&c).is_some_and(|c| {
                        *c != 0 && 64 - c.leading_zeros() <= trailing_zeros(v, &defs, &consts, memo, 16)
                    })
                };
                if fits(x, y, &mut memo) || fits(y, x, &mut memo) {
                    rewritten.push((fi, bi, ii));
                }
            }
        }
    }
    for (fi, bi, ii) in &rewritten {
        module.functions[*fi].blocks[*bi].instructions[*ii].class.opcode = Op::IAdd;
    }
    rewritten.len()
}
