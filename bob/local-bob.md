### How to use with local BoB
Create a `.env` file on the same level as the docker-compose.yml with following content:

#### static host resolution
```
BOB_IP=<IP-of-bob>
BOB_TLD=<full-TLD-except-service-endpoints>
```
Example:
```
BOB_IP=192.168.0.5
BOB_TLD=55ccb57ae329e48ecf6b9ec7d42651a7.bob.local
```
#### local self signed certificate
Copy the bob self signed certificate (retrieved during BoB setup) into the root level of the repo and name it `bob.local.pem`.
E.g. 
```
cp ~/bob/balena/ca-bundle.55ccb57ae329e48ecf6b9ec7d42651a7.bob.local.pem bob.local.pem
```

### Scaling
docker composes to scale one docker compose file. Docker will then create as many as defined container instances of the service defined in the docker-compose.yml file.
The usage is
` docker-compose up --scale os=N `
e.g.:
` docker-compose up --scale os=8 `