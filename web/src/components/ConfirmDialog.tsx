"use client";

import { useEffect, useRef, useState } from "react";
import s from "./Settings.module.css";
import ui from "./ui.module.css";

const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

/** A destructive action's dialog: neutral on the row, only this confirm button is red (DESIGN.md). */
export function ConfirmDialog({
  title,
  text,
  action,
  typed,
  onClose,
  onConfirm,
}: {
  title: string;
  text: string;
  action: string;
  /** A word the owner types before the button works, for what can't be undone. */
  typed?: string;
  onClose: () => void;
  onConfirm: () => Promise<void>;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const [word, setWord] = useState("");
  useEffect(() => ref.current?.showModal(), []);
  return (
    <dialog
      ref={ref}
      className={`m-rise ${s.dialog}`}
      onClose={onClose}
      aria-labelledby="confirm-title"
    >
      <h3 id="confirm-title" className="t-subtitle">
        {title}
      </h3>
      <p className={`t-small ${s.sub}`}>{text}</p>
      {typed && (
        <label className={`t-meta ${s.dim} ${s.typed}`}>
          Type {typed} to confirm
          <input
            className={`t-body ${ui.input}`}
            value={word}
            autoComplete="off"
            autoCapitalize="none"
            spellCheck={false}
            onChange={(e) => setWord(e.target.value)}
          />
        </label>
      )}
      {error && <p className={`t-meta ${s.error}`}>{error}</p>}
      <div className={s.dialogActions}>
        <button type="button" className={`t-label ${ui.btn}`} onClick={() => ref.current?.close()}>
          Cancel
        </button>
        <button
          type="button"
          className={`t-label ${ui.btn} ${ui.destroy}`}
          disabled={busy || (typed !== undefined && word.trim().toLowerCase() !== typed)}
          onClick={async () => {
            setBusy(true);
            setError(undefined);
            try {
              await onConfirm();
            } catch (e) {
              setError(message(e));
              setBusy(false);
            }
          }}
        >
          {action}
        </button>
      </div>
    </dialog>
  );
}
