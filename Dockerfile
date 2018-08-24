FROM amazonlinux:latest

RUN yum update -y && \
    yum group install Development Tools -y && \
    yum install wget ruby ruby-devel rubygem-rake openssl-devel pcre-devel -y && \
    yum clean all

RUN cd /usr/local/src/ && git clone https://github.com/matsumotory/ngx_mruby.git
ENV NGINX_CONFIG_OPT_ENV --with-http_stub_status_module --prefix=/usr/local/nginx --with-stream --without-stream_access_module
COPY build_config.rb /usr/local/src/ngx_mruby/
RUN cd /usr/local/src/ngx_mruby && sh build.sh && make install

COPY nginx/conf /usr/local/nginx/conf
COPY healthcheck.rb .

CMD ["/usr/local/nginx/sbin/nginx"]

