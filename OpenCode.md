# OpenCode Guidelines
## Setup & Run
- bundle install && yarn install && bin/rails db:create db:migrate
- bin/rails server
## Testing
- bin/rails test
- bin/rails test TEST=path/to/file_test.rb[:line]
## Lint & Format
- bundle exec rubocop --auto-correct && bundle exec rubocop
- yarn build:css
## Style Guide
- 2-space indent; 8 chars
- snake_case files/methods, CamelCase classes, UPPER_SNAKE constants
- group requires: stdlib, gems, relative
- lean controllers; services for business logic
## Error Handling
- rescue specific errors; avoid broad rescue; log unexpected
- wrap API calls in service objects with retries
## Cursor & Copilot
- include rules from `.cursor/rules/` & `.github/copilot-instructions.md` if present
