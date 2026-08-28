// BUILD-026: const enum export (targets .ts only)
export const enum Status { Active, Inactive }

// BUILD-040: process.exit in library code (targets .ts .js)
process.exit(1);

// BUILD-043: .default after require (targets .ts .js)
const lib = require('my-lib').default;
