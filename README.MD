# Nginx & Lua
Nginx 1.18 with Lua support based on Debian.
# Build
```
docker build -t nginx:v1 .
```

# Run 
```
docker run -d -p 80:80 nginx:v1 -v $(pwd)/conf.d/localhost.conf:/etc/nginx/conf.d/localhost.conf 
```

# Run docker-compose
```
docker-compose up --build
```
