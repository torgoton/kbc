ifeq ($(CONTAINERIZED),1)
up: up-container

down: down-container

tail: tail-container
else
up:
	@bin/dev

down:
	@echo "Stopping the application..."
	@pkill -f 'puma'

tail:
	@echo "Tailing the application logs..."
	tail -f log/*.log
endif

up-container:
	@docker compose up --build

down-container:
	@echo "Stopping the application..."
	@docker compose down

tail-container:
	@echo "Tailing the application logs..."
	@docker compose logs -f web

