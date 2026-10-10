/**
 * Replies typed but not sent, by question, until the page reloads (#992): one survives its detail
 * moving between the phone and wide layouts, and a visit to Settings, as Android keeps them.
 */
export const drafts = new Map<string, string>();
