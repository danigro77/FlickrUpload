FlickrUpload
============
```
ruby create_flickr_user.rb [options]
    -u, --user USER                  Input Flickr username
    -k, --api_key API_KEY            Input Flickr api_key
    -s SHARED_SECRET,                Input Flickr shared_secret
        --shared_secret
    -p, --permit PERMIT              possible: read, delete, write
    -h, --help                       Display this screen
```

```
ruby download_flickr_images.rb [options]
    -u, --user USER                  Input your Flickr user name
    -t, --target TARGET              Input the full path to target directory
    -s, --source S1,S2,S3            Input the directories you want to download. Example: -s bla_1,'bla 2' 
Use -A if you want to download all.
    -A, --all                        Use -A if you want to download all albums from Flickr
    -a, --album                      If this is set, you want all images in your target directory. 
Else: It creates directories with the source album name inside your target directory.
    -h, --help                       Display help screen
```

```
ruby upload_to_flickr.rb [options]
    -u, --user USER                  Input your Flickr user name
    -p, --path PATH                  Input the full source path
    -m, --mode MODE                  Set upload mode [n/new, s/skip, a/add] for behavior when album exists
    -h, --help                       Display help screen
```
