# On linux
# - ensure valkey is running before starting the app
# - maybe shut it down when stopping

up:
	@if [ "$(shell systemctl is-active valkey)" != "active" ]; then \
		echo "valkey is not running. Starting valkey..."; \
		systemctl start valkey; \
	else \
		echo "valkey is already running."; \
	fi
	@echo "Starting the application..."
	bundle exec rails server

down:
	@echo "Stopping the application..."
	@pkill -f 'rails/server.rb'

