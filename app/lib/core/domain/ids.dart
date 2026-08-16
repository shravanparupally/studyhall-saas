/// Opaque, globally-unique identifier wrappers, per
/// docs/14_Domain_Model.md §14.4 ("Identity Value Objects"). Zero-cost at
/// runtime (extension types compile away) — used instead of a bare
/// [String] anywhere an ID crosses a repository/use-case boundary, so a
/// caller can't accidentally pass an [OrganizationId] where a
/// [BranchId] was expected.
library;

/// Identifies one Organization (tenant).
extension type const OrganizationId(String value) {}

/// Identifies one Branch within an Organization.
extension type const BranchId(String value) {}
