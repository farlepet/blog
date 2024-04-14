Source for my blog
==================

Building:
```
docker buildx build --platform=<target platform> . -t blog --output type=tar,dest=./blog.tar
```

Importing:
```
docker import blog.tar blog_server
```

NOTE: Using import does not retain all the info that might be exported from a
docker save. The container will need to be started with the following command
provided (the last part may or may not be required):
```
... nginx -g "daemon off;"
```

