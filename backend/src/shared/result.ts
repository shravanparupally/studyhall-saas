/**
 * The TypeScript-side mirror of the Dart `Result`/`Failure` hierarchy in
 * app/lib/core/result/ (docs/15_Technical_Architecture.md §15.17). Every
 * Application-layer use case in this backend returns a `Result<T>` instead
 * of throwing, so a caught infrastructure error can never escape as itself
 * — the same rule stated once for the whole stack, enforced identically on
 * both sides of the network call.
 */

export type Failure =
  | { kind: 'network'; message?: string }
  | { kind: 'validation'; message?: string }
  | { kind: 'permission'; message?: string }
  | { kind: 'conflict'; message?: string }
  | { kind: 'notFound'; message?: string };

export type Result<T> = { ok: true; value: T } | { ok: false; failure: Failure };

export function success<T>(value: T): Result<T> {
  return { ok: true, value };
}

export function failure<T>(failure: Failure): Result<T> {
  return { ok: false, failure };
}
