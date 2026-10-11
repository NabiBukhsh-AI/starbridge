import {
  type BodyOf,
  type ItemKind,
  type Member,
  type SealedItem,
  seal as sealChecked,
  toWellFormed,
} from "@starbridge/protocol";

/**
 * `seal` for bodies built from agents' and tools' text, which can hold a lone surrogate that the
 * protocol refuses: each one becomes U+FFFD (#1090).
 */
export function seal<K extends ItemKind>(
  kind: K,
  body: BodyOf<K>,
  signer: { id: string; signKey: Uint8Array },
  recipients: Pick<Member, "id" | "boxPk">[],
): SealedItem & { kind: K } {
  return sealChecked(kind, toWellFormed(body), signer, recipients);
}
