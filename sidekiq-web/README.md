```
ssh -N -L 0.0.0.0:6379:localhost:6379 root@server.ip -p server_port

docker-compose run --service-ports --entrypoint bash puma

vim config.yml -> host: 192.168.99.1 # or localhost for linux

cd sidekiq-web

rackup -o 0.0.0.0

OS X: http://192.168.99.1:9292
Linux: http://localhost:9292
```
