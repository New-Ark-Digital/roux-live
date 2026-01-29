# Set up the project
setup:
	mise exec -- mix deps.get
	mise exec -- mix assets.setup
	mise exec -- mix assets.build

# Run the server
run:
	mise exec -- mix phx.server

# Run tests
test:
	mise exec -- mix test

# Run precommit checks
check:
	mise exec -- mix precommit
