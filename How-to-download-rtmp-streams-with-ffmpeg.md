# How to download RTMP streams (m3u8) with ffmpeg

Use the following in your profile:
```bash
m3udlreal ()
{
    ffmpeg -rw_timeout 10000000 -re -i $1 -c copy -bsf:a aac_adtstoasc "$2"
}

m3udl ()
{
    ffmpeg -rw_timeout 10000000 -i $1 -c copy -bsf:a aac_adtstoasc "$2"
}
```

for MPD streams use the dash-mpd cli binary.