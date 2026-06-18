CONTAINERIZED ?= 1

ifeq ($(CONTAINERIZED),1)
up:
	@docker compose up --build

down:
	@echo "Stopping the application..."
	@docker compose down

tail:
	@echo "Tailing the application logs..."
	@docker compose logs -f web
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

