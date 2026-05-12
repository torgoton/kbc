up:
	@docker compose up --build

down:
	@echo "Stopping the application..."
	@docker compose down

tail:
	@echo "Tailing the application logs..."
	@docker compose logs -f web

