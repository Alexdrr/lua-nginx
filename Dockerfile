ARG DEBIAN_VERSION='9'
FROM debian:${DEBIAN_VERSION} AS builder
ENV DEBIAN_FRONTEND noninteractive
ARG DEBIAN_CODENAME='buster'

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    g++ \
    libgeoip-dev \
    libpcre3-dev \
    libssl-dev \
    libluajit-5.1-dev \
    make \
    zlib1g-dev 

WORKDIR /root
ARG LUAJIT_VERSION='2.1.0-beta3'
RUN mkdir -p /root/modules && \
    cd /root/modules && \
    curl https://github.com/openresty/luajit2/archive/v${LUAJIT_VERSION}.tar.gz -Lo luajit2-${LUAJIT_VERSION}.tar.gz && \
    tar -xzvf luajit2-${LUAJIT_VERSION}.tar.gz   && \
    cd luajit2-${LUAJIT_VERSION} && \
    make -j8 && make install


ARG LUA_VERSION='0.10.19'
RUN cd /root/modules && \
    curl https://github.com/openresty/lua-nginx-module/archive/v${LUA_VERSION}.tar.gz -Lo lua-nginx-module-${LUA_VERSION}.tar.gz && \
    tar -xzvf lua-nginx-module-${LUA_VERSION}.tar.gz

ARG NGX_DEVIL_VERSION='0.3.1'
RUN cd /root/modules && \
    curl https://github.com/vision5/ngx_devel_kit/archive/v${NGX_DEVIL_VERSION}.tar.gz -Lo ngx_devel_kit-${NGX_DEVIL_VERSION}.tar.gz && \
    tar -xzvf  ngx_devel_kit-${NGX_DEVIL_VERSION}.tar.gz

ARG LUA_RESTY_CORE_VERSION='0.1.21'
RUN cd /root/modules && \
    curl https://github.com/openresty/lua-resty-core/archive/v${LUA_RESTY_CORE_VERSION}.tar.gz -Lo lua-resty-core-${LUA_RESTY_CORE_VERSION}.tar.gz && \
    tar -xzvf lua-resty-core-${LUA_RESTY_CORE_VERSION}.tar.gz && \
    cd lua-resty-core-${LUA_RESTY_CORE_VERSION} && \
    make && make install

ARG LUA_RESTY_LRUCACHE_VERSION='0.10'
RUN cd /root/modules && \
    curl https://github.com/openresty/lua-resty-lrucache/archive/v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz  -Lo lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION}.tar.gz && \
    tar -xzvf lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION}.tar.gz && \
    cd lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION} && \
    make && make install

ARG NGINX_VERSION="1.18.0"
# Пришлось вбить костыль, иначе при сборке не видит директорию Luajit
ARG LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_LIB=$LUAJIT_LIB
ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ENV LUAJIT_INC=$LUAJIT_INC
ARG LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH

ARG NGX_CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC"
ENV NGX_CFLAGS=$NGX_CFLAGS
ARG NGX_LDOPT="-Wl,-rpath,/usr/local/lib -Wl,-z,relro -Wl,-z,now -fPIC"
ENV NGX_LDOPT=$NGX_LDOPT
ARG NGINX_BUILD_CONFIG="\
		--prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--lock-path=/var/lock/nginx.lock \
		--pid-path=/run/nginx.pid \
		--modules-path=/usr/lib/nginx/modules \
		--http-client-body-temp-path=/var/lib/nginx/body \
		--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
		--http-proxy-temp-path=/var/lib/nginx/proxy \
		--http-scgi-temp-path=/var/lib/nginx/scgi \
		--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
		--with-compat \
		--with-debug \
		--with-pcre-jit \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--with-http_realip_module \
		--with-http_auth_request_module \
		--with-http_v2_module \
		--with-http_dav_module \
		--with-http_slice_module \
		--with-threads \
        --user=nginx \
        --group=nginx \
        --add-module=/root/modules/ngx_devel_kit-${NGX_DEVIL_VERSION} \
        --add-module=/root/modules/lua-nginx-module-${LUA_VERSION} \
       " 
		#--http-log-path=/var/log/nginx/access.log \
		#--error-log-path=/var/log/nginx/error.log \

RUN curl https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzvf nginx-${NGINX_VERSION}.tar.gz && \
	mkdir -p /var/cache/nginx/client_temp \
	   /var/cache/nginx/proxy_temp \
	   /var/cache/nginx/fastcgi_temp \
	   /var/cache/nginx/uwsgi_temp \
	   /var/cache/nginx/scgi_temp && \
	cd nginx-${NGINX_VERSION} && \
	./configure ${NGINX_BUILD_CONFIG} --with-cc-opt="$(NGX_CFLAGS)" --with-ld-opt="$(NGX_LDOPT)" --with-debug && \
    make && make install

ARG DEBIAN_VERSION='9'
FROM debian:${DEBIAN_VERSION}
WORKDIR /root/    
COPY --from=builder /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/lib/lua/0.10.19/resty /etc/nginx/resty
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

RUN mkdir -p /var/www/html  \
              /var/lib/nginx \
              /var/cache/nginx \
              /usr/local/share/lua/5.1 && \
            #  /etc/nginx/conf.d && \
    addgroup --system --gid 101 nginx &&  \
    adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx && \
   # Еще один костылек чтобы nginx мог видеть lua-core из директории запущенным из /usr/sbin/nginx
    ln -s /etc/nginx/resty /usr/local/share/lua/5.1/resty
COPY nginx.conf /etc/nginx/nginx.conf
COPY html/index.html /var/www/html/index.html
CMD ["nginx", "-g", "daemon off;"]