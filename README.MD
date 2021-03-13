# Nginx & Lua
Nginx 1.18 with Lua support based on Debian.
# Build
```
docker build -t nginx:v1 .
```

# Run 
```
docker run -d -p 80:80 nginx:v1 -v $(pwd)/conf.d/:/etc/nginx/conf.d 
```

# Run docker-compose
```
docker-compose up --build
```
