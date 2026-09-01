# UTK Knapsack

A [Hyku Knapsack](https://github.com/samvera-labs/hyku_knapsack) for the University of Tennessee,
Knoxville. The Knapsack is a Rails engine that wraps Hyku: Hyku itself lives in the `hyrax-webapp/`
submodule, and this repository holds only what is unique to UTK or differs from Hyku.

Precedence is inverted from a normal Rails app — the engine overrides the application. Views,
translations, decorators, and initializers here win over their `hyrax-webapp/` counterparts.

Knapsack major versions track Hyku major versions; this is Knapsack 7, so it targets Hyku 7.

## Setup

```bash
git clone https://github.com/notch8/utk_knapsack.git
cd utk_knapsack
git remote add prime https://github.com/samvera-labs/hyku_knapsack
git submodule init && git submodule update
git branch required_for_knapsack_instances origin/required_for_knapsack_instances
```

Three things have to be true before the stack boots:

- **The submodule is populated.** A fresh clone leaves `hyrax-webapp/` empty and `bin/rails` says so.
- **A local `required_for_knapsack_instances` branch exists.** Hyku's Gemfile pins `hyku_knapsack`
  to that branch and bundler resolves it against this checkout, so the branch has to exist locally.
  CI does the same thing through `bin/checkout_all.sh`.
- **`prime` points at `samvera-labs/hyku_knapsack`**, the upstream Knapsack. `origin` is UTK's repo;
  Hyku prime is `samvera/hyku`, the submodule's remote.

## Running the stack

This is a Fedora-free stack. Wings is off, so Hyrax stores everything in Postgres through Valkyrie
and no `fcrepo` container starts — it sits behind a `fedora` compose profile, waiting for anyone who
needs the old path back. `docker-compose.override-nofcrepo4.yml` is what turns Wings off, so keep it
in `COMPOSE_FILE` below.

Development runs in Docker via [stack_car](https://github.com/notch8/stack_car). Run everything from
the Knapsack root, **never** from inside `hyrax-webapp/`.

`.env.development` holds your machine-specific settings and is gitignored, so it never leaves your
checkout. Any `sc` command writes it from a template if it is missing, so there is nothing to create
by hand. It is also where compose overrides belong: name every file you want in `COMPOSE_FILE` and
`sc up` picks them up, with no `-f` flags to remember.

```bash
# .env.development
WEB_PORT=3000:80   # if you are not using dory

# no-Fedora stack; drop the last file to run with Fedora again
COMPOSE_FILE=docker-compose.yml:docker-compose.override.yml:docker-compose.override-nofcrepo4.yml
```

Setting `COMPOSE_FILE` replaces the default list, so `docker-compose.yml` and the implicit
`docker-compose.override.yml` have to be named explicitly if you want them.

```bash
gem install stack_car
sc proxy cert && sc proxy up   # once per stack_car version
sc build
sc up
sc sh                          # shell into the web container
```

By default, the app is then at `https://admin-utk-knapsack.localhost.direct/`, and a tenant at
`https://{tenant}-utk-knapsack.localhost.direct/`. The `utk-knapsack` half is `APP_NAME`, which
stack_car derives from the directory name.

Inside the container the Knapsack root is `/app/samvera` and Hyku is `/app/samvera/hyrax-webapp`.
`docker-compose.yml` bind-mounts `.:/app/samvera` and sets `BUNDLE_LOCAL__HYKU_KNAPSACK=/app/samvera`
so the local Knapsack is used instead of the released gem.

`docker-compose.override.yml` parks `web` and `worker` on `sleep infinity`, mounts `../gems/` for
working on checked-out gems, and turns on `HYRAX_FLEXIBLE` — start Rails yourself from `sc sh`.
`docker-compose.override-nofcrepo4.yml` runs Wings off: Hyrax on Postgres alone, no Fedora container.

## Troubleshooting

**`initialize_app` exits 11 on `sc up`.** Everything else comes up healthy and the stack stops with
`service "initialize_app" didn't complete successfully: exit 11`. 11 is bundler's exit code, and it
generally means the bundle inside the container is behind the Gemfile. Restarting the app containers
is usually enough:

```bash
docker compose restart web worker
```

If it comes back, install the bundle by hand — this is also what fixes
`The git source https://github.com/notch8/willow_sword.git is not yet checked out`:

```bash
sc sh
cd /app/samvera && bundle install
```

## Migrations

`initialize_app` runs `bin/db-migrate-seed.sh` on `sc up`, which creates, migrates, and seeds the
development database only when migrations are pending. To run them yourself, from `sc sh`:

```bash
cd /app/samvera/hyrax-webapp
bundle exec rails db:migrate
```

Rake tasks are the exception to the run-from-the-root rule: they need `Rails.root`, and
`bin/rails db:migrate` from `/app/samvera` fails with `Unrecognized command`. The Knapsack has no
`db/` of its own, so the migrations are Hyku's.

## Tests and lint

The test database is separate from development and nothing creates it for you. Once, from `sc sh`:

```bash
cd /app/samvera/hyrax-webapp
RAILS_ENV=test bundle exec rails db:create db:migrate
```

Without it every spec dies in `rails_helper.rb` at `maintain_test_schema!` with
`database "hyku_test" does not exist`. Note that `db:migrate` rewrites `hyrax-webapp/db/schema.rb`,
which shows up as a dirty submodule.

Then, from the Knapsack root (`/app/samvera`), not the submodule:

```bash
bundle exec rspec                                   # all Knapsack specs
bundle exec rspec spec/initializers/hyrax_spec.rb:6 # a single example
bundle exec rubocop --parallel
```

`.rubocop.yml` inherits `bixby` and excludes `hyrax-webapp/**/*`; the submodule polices itself.

## Development

### Overrides

Before overriding anything, decide whether the change is really a Hyku bug or feature. If it is,
branch inside `hyrax-webapp/` and contribute it upstream — that is the point of this structure. Only
UTK-specific behavior belongs here.

Any file with `_decorator.rb` in `app/` or `lib/` is loaded automatically, along with the classes in
`app/`. Prefer a decorator over copying a whole file. See the upstream notes on
[decorators and overrides](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides).

Theme files (views, CSS, images) can be added here as well; `lib/hyku_knapsack/engine.rb` is where
the view path, translation, initializer, and asset precedence is set up.

### Gems

Do not add gems to the `Gemfile` or the gemspec. The Knapsack `Gemfile` reads Hyku's, so adding a gem
here mutates Hyku's bundle and risks pushing install-specific dependencies upstream. Add gems to
[`bundler.d/example.rb`](./bundler.d/example.rb) instead, via
[bundler-inject](https://github.com/kbrock/bundler-inject) (`gem`, `override_gem`, `ensure_gem`).

### Generating a work type

```bash
bundle exec rails generate hyku_knapsack:work_resource WorkType
bundle exec rails generate hyku_knapsack:work_resource WorkType --flexible  # skips static schema YAML
```

Use this generator, **not** `hyrax:work_resource` — it writes every file with a `../` prefix so the
output lands in the Knapsack instead of the submodule.

### Comparing against upstream

`bin/knapsacker` lists what differs between two checkouts, prefixing each file `=` (identical),
`+` (unique to yours), or `Δ` (modified):

```bash
bin/knapsacker -y . -u ./hyrax-webapp
```

## Keeping up to date

Move the Hyku submodule to the HEAD of its remote's default branch — `.gitmodules` names no branch,
so `git submodule set-branch` is what pins it to something else:

```bash
git submodule update --remote
```

Pull in fixes from the upstream Knapsack:

```bash
git fetch prime && git merge prime/main
```

## CI

`.github/workflows/build-test-lint.yaml` delegates to the reusable `notch8/actions` workflows for
build, test, lint, and reporting. Deploys are `workflow_dispatch`-only, against the templates in
`ops/`.

## License

Available as open source under the terms of the [Apache 2.0](https://opensource.org/license/apache-2-0/) license.
