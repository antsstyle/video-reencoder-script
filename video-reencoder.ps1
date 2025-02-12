using assembly microsoft.visualbasic
using namespace microsoft.visualbasic

# The base path to search for videos to re-encode.
# Replace with the path you want to use.
$basePath = "C:\Your Path Here\"
# Stop after re-encoding this many videos. Set to 1 to re-encode only the first video found in the folder.
$numFilesToProcess = 1
$files = @()
# The minimum size of any video to re-encode, in MB.
# Videos of less than this filesize will be skipped (to avoid re-encoding videos that are already efficiently encoded).
$minFileSize = 0
# The maximum duration of any video to encode, in seconds.
# Videos longer than this will be skipped.
$maxDuration = 5400
# The maximum width of any video to encode, in pixels.
# Videos wider than this will be skipped.
$maxResolutionWidth = 1920
# The output video codec to use. See ffmpeg documentation for possible choices.
$outputVideoCodec = "libx265"
# The output audio codec to use. See ffmpeg documentation for possible choices.
$outputAudioCodec = "aac"
# The suffix to append to any newly re-encoded video, before the file extension.
# E.g. "_x265" output suffix will cause "video.mp4" to be saved re-encoded as "video_x265.mp4"
$outputSuffix = "_x265"
# The CRF (constant rate factor) to use for re-encoding, which will determine the output video quality.
$crf = "18";
# The encoding preset, see below.
$preset = "veryfast"
# The maximum number of frames between each keyframe, see below.
$keyInt = "24";
# Explanation of ffmpeg arguments used here:
#
# -n: do not overwrite a file that already exists
# -c:v libx265: use x265/HEVC encoding
# -c:a aac: use AAC audio encoding
# -preset veryfast: the encoding preset, a time/quality/filesize tradeoff. See FFmpeg documentation.
# -x265-params "keyint=$keyInt": force keyframes to be generated at a maximum of keyInt frame intervals.
# This affects how precisely the video can be seeked when playing; more frequent keyframes means a higher file size.
# -crf $crf: set the Constant Rate Factor (CRF) to determine output quality.
# For x264 videos, between 18-23 is considered a normal quality range; for x265, 23-28. Lower equals higher quality and higher filesize, with diminishing returns.

# When set to 1, the old video file will be moved to the recycle bin.
$moveOldFileToRecycleBin = 1
# When set to 1, the new video will be given the filename of the old video, effectively replacing it.
# This can only be enabled when moveOldFileToRecycleBin is set to 1, to avoid inadvertently overwriting the old video file.
$renameNewVideoToOldVideoName = 1

$baseArgumentList = ' -n -c:v ' + $outputVideoCodec + ' -c:a ' + $outputAudioCodec + ' -preset ' + $preset + ' -crf ' + $crf

if ($outputVideoCodec -eq "libx265") {
	$baseArgumentList = $baseArgumentList + ' -x265-params "keyint=' + $keyInt + '" '
} elseif ($outputVideoCodec -eq "libx264") {
	$baseArgumentList = $baseArgumentList + ' -x264-params "keyint=' + $keyInt + '" '
}

# Get all files in the target directory, recursively (traverse all subfolders as well).
$allFilesInDirectory = Get-Childitem -Attributes !Directory+!System -Path $basePath -File -Recurse -force -ErrorAction SilentlyContinue -Name

# Counts how many videos have been re-encoded, so we can stop when we have reached the maximum number set earlier.
$found = 0

$validVideoExtensions = @("mp4")

ForEach ($fileInDirectory in $allFilesInDirectory) {
	$lastDot = $fileInDirectory.LastIndexOf(".") + 1
	if ($lastDot -eq 0) {
		continue
	}
	$extension = $fileInDirectory.SubString($lastDot).ToLower()
	if ($extension -notin $validVideoExtensions) {
		continue
	}
	$fullFilePath = $basePath + $fileInDirectory
	$fileInfo = Get-Item $fullFilePath
	$fileSizeMB = $fileInfo.Length / 1MB
	# If this file is bigger than the minimum filesize, skip it.
	if ($fileSizeMB -lt $minFileSize) {
		continue
	}
	# The quoted filepath is used for ffprobe to prevent syntax errors.
	$quotedFilePath = '"' + $fullFilePath + '"'
	# Returns only the video codec, to determine if the given video is already encoded in x265.
	$videoCodecResult = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $quotedFilePath
	# If the video is already x265 encoded (written as hevc in ffprobe), skip it.
	if ($videoCodecResult -eq "hevc") {
		continue
	}
	# Returns only the video resolution, to determine if this is a 4K video.
	# Those don't lose much filesize when re-encoded and are much slower to re-encode, so we skip them.
	$videoResolutionResult = ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 $quotedFilePath
	$integerWidth = [int]$videoResolutionResult
	# If the video is greater than 1920px in width, skip it.
	if ($integerWidth -gt $maxResolutionWidth) {
		continue
	}
	$durationResult = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $quotedFilePath
	$doubleDuration = [double]$durationResult
	# If the video is more than 1.5 hours long, skip it.
	if ($doubleDuration -gt $maxDuration) {
		continue
	}
	$files += $fullFilePath
	$found++
	if ($found -eq $numFilesToProcess) {
		break
	}
}
	
ForEach ($file in $files) {
	# Write-Host ("File: " + $file)
}

ForEach ($file in $files) {
	if (!(Test-Path $file -PathType leaf)) {
		Write-Host ("File with path " + $file + " does not exist, skipping.")
		continue
	}
	$oldFileName = $file.SubString($file.LastIndexOf("\") + 1)
	$newFile = $file.Substring(0, $file.IndexOf(".")) + $outputSuffix + ".mp4"
	$fileArgumentList = ' -i "' + $file + '" ' + $baseArgumentList + ' "' + $newFile + '"'
	Start-Process ffmpeg -ArgumentList $fileArgumentList -NoNewWindow -Wait
	if ($moveOldFileToRecycleBin -eq 1) {
		[FileIO.FileSystem]::DeleteFile($file, 'OnlyErrorDialogs', 'SendToRecycleBin')
		if ($renameNewVideoToOldVideoName) {
			Write-Host ("Moving to old file name: " + $oldFileName)
			Rename-Item -Path $newFile -NewName $oldFileName
		}
	}
}
