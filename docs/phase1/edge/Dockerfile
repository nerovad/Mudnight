# nginx with the RTMP module already compiled in. Popular, stable base image.
# We only swap in our own config so the HLS layout matches production.
FROM tiangolo/nginx-rtmp
COPY nginx.conf /etc/nginx/nginx.conf
