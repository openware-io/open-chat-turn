FROM node:24-alpine AS dependencies

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

FROM node:24-alpine

WORKDIR /app
ARG IMAGE_NAME
ARG IMAGE_VERSION
ARG IMAGE_REVISION
ARG IMAGE_CREATED
ARG IMAGE_SOURCE
LABEL org.opencontainers.image.title=$IMAGE_NAME \
      org.opencontainers.image.version=$IMAGE_VERSION \
      org.opencontainers.image.revision=$IMAGE_REVISION \
      org.opencontainers.image.created=$IMAGE_CREATED \
      org.opencontainers.image.source=$IMAGE_SOURCE
ENV NODE_ENV=production
COPY --from=dependencies /app/node_modules ./node_modules
COPY index.js package.json ./

USER node
EXPOSE 3478/udp
CMD ["node", "index.js"]
