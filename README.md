# video-reencoder-script
A Windows PowerShell script for re-encoding videos in a directory to x265.

## Prerequisites

You will need to have FFmpeg installed and available on your PATH (which should be the case after installing it).

## Usage

The script is configured using various variables at the start of the script, explained in the comments, and run from powershell without arguments.

# Understanding video re-encoding performance and requirements

Re-encoding a video from x264 to x265 can provide a significant saving on filesize without sacrificing much quality (all re-encoding that isn't lossless will incur some quality loss, but unless you keep re-encoding the same file, it will not be noticeable).

Be aware that x265 is CPU-intensive, and will require a significant amount of time to re-encode anything other than small videos, depending on the power of your CPU. On my i7-9700K, re-encoding a 40 minute 1080p video takes between 30-40 minutes, as a rough idea. Videos that are already encoded fairly efficiently will often see little filesize saving.
