Nope - Initial plan is to deploy to a local NAS, and use SQLite3 for the database.
Next plan is to install on a local computer

## Initial Preparation

### Setup Docker and a Registry
https://computingforgeeks.com/install-and-use-docker-registry-on-fedora/
- install docker
- reinstall iptables package
- sudo dnf install -y iptables-legacy
- docker starts
- install docker-distribution (has registry)
- add docker config file for insecure local host(s) and restart
- tag the images with a prefix of "machine:port/"
- ensure you can push an image with "docker push"

## Make an image
### Development
- docker build --tag kbcdev --file Dockerfile-dev . # note the period

## Tag and Push the image
- docker tag #{IMAGE} #{HOST}:#{PORT}/#{NAME}
- docker push #{TAG} # this TAG must start with a host so docker knows where to push it

## Run the image
- log in to the server
- docker pull #{TAG}
- docker run --rm --name kbcdev -p 80:3000 #{TAG} bin/rails server -b 0.0.0.0 -p 3000
- run migrations?
- use a browser to fetch the home page (http://#{HOST}/)

NEXT STEP
- ~~decide where the database will live and get it running~~
- change database to PostgreSQL, like a real app
