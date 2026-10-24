# InkProf working preferences

## Immutable measurement originals

Original measurement files must never be overwritten, deleted or sent to Trash by InkProf. Remeasurements, corrections and analyses must use separate files/revisions with provenance. Print-copy operations must preserve the original project, measurements and profiles. Failure/cancellation cleanup must only affect newly created temporary/output files, never a source project or existing measurement. Project renames must not overwrite another folder, cross to a different parent, or target Trash. Do not bypass integrity checks or silently rehash changed content.

When creating or updating InkProf documentation PDFs, also copy every resulting PDF to `/Users/christer/Downloads/`, keeping its filename. This is the user's default delivery location; do not ask again. Keep the repository copy as the source artifact and verify that the Downloads copy matches it. Include handbooks, presentations and other updated documentation PDFs. Do not export private project reports or measurement data unless requested.

## Page layout

Never leave a heading at the bottom of a page with its body text, figure or table starting on the next page. Keep every heading together with the first meaningful part of the following content. If they do not fit, move the heading and that content to the next page. Apply this to certificates, supplements, documentation PDFs and paginated/printed HTML. Verify page boundaries when reviewing generated output.

## Registered project reports

Do not regenerate or overwrite files inside an already registered project export folder directly. Use a new workflow export for report revisions; use a temporary copy for layout tests. Preserve existing measurements, profiles, approvals and recorded checksums. If an authorised repair is needed after an accidental report overwrite, first audit all mismatches, preserve the previous manifests, document the exact old/new hashes, and verify both the project manifest and workflow artifact integrity after the repair. Never silently rehash unrelated changes.
