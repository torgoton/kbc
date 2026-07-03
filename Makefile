CONTAINERIZED ?= 1
KBC_HOST_PORT ?= 3000
KBC_DB_PORT ?= 5432

ifeq ($(CONTAINERIZED),1)
up:
	@docker compose up --build

down:
	@echo "Stopping and removing containers..."
	@docker compose down

stop:
	@docker compose stop

tail:
	@echo "Tailing the application logs..."
	@docker compose logs -f web

reset:
	@read -p "This will delete the local database. Are you sure? [y/N] " confirm && \
		case "$$confirm" in [yY]*) docker compose down -v ;; *) echo "Aborted." ; exit 1 ;; esac
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
