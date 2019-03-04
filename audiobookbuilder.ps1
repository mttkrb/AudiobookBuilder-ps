#inspired by https://ubuntuforums.org/showthread.php?t=1418085
# uses FFMPEG,MP4Box and MP4Chaps(from MP4v2)

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[System.Reflection.Assembly]::LoadWithPartialName("taglib-sharp") 2>$null
$audioFiles = Get-ChildItem -Include "*.mp3", "*.m4a" -Recurse
$chapterFileName ="chapterFile.chap"
$first = $audioFiles | Select-Object -first 1
$fileInfo = [TagLib.MPEG.File]::Create($first)
$AudiobookArtist= $fileInfo.Tag.FirstArtist
$AudiobookAlbum=$fileInfo.Tag.Album
$AudiobookTitle=$fileInfo.Tag.Album
$resultFileName= "{0}_{1}.m4b" -f ($AudiobookArtist, $AudiobookAlbum)
$resultTmpFileName ="tmp_{0}_{1}.m4b" -f ($AudiobookArtist, $AudiobookAlbum)
$chapterContent =""
$format=""
$cnt=0
$CatArguments=""
$converted = $false
$duration = New-TimeSpan 

if(Test-Path $resultTmpFileName)
{
    Remove-Item $resultTmpFileName
}
if(Test-Path $resultFileName)
{
    Remove-Item $resultFileName
}
if(Test-Path $chapterFileName)
{
    Remove-Item $chapterFileName
}
Write-Host Convert files in Folder $audioFiles

foreach($audio in $audioFiles)
{    
    $cnt++
    $audioM4a = $audio.BaseName + ".m4a"   
    if($audio.Extension.Equals(".mp3"))
    {           
        if(!(Test-Path $audioM4a) -or (Get-ChildItem $audioM4a ).Length -eq 0)
        {            
            Write-Host Convert $audio.Name
            ffmpeg -i $audio -y -c:a aac -ab 192k -ar 44100 -vn -f MP4 $audioM4a 2>$null
            $converted=$true
        }
        else
        {
            $converted=$false
        }        
    }        
    
    if($converted -or $audio.Extension.Equals(".m4a"))
    {
        $fileInfo = [TagLib.MPEG.File]::Create((Join-Path (Get-Item -Path ".\") $audioM4a))        
        MP4Box -quiet -cat $audioM4a $resultTmpFileName 2> $null    
        $chapterContent += ("CHAPTER{0}={1:hh\:mm\:ss\:fff}`n" -f ($cnt, $duration))
        $chapterContent += ("CHAPTER{0}NAME={1}-{2} {3}`n" -f ( $cnt, $fileInfo.Tag.Disc, $fileInfo.Tag.Track, $fileInfo.Tag.Title))
        $duration +=$fileInfo.Properties.Duration
        Write-Host "Add"$audioM4a to $resultTmpFileName Total Time: $duration
    }
}

$chapterContent | Out-File $chapterFileName 
Write-Host Add Chapter Informations to $resultTmpFileName
Mp4Box -add $resultTmpFileName -chap $chapterFileName $resultFileName 2>$null

Write-Host Write artist and album name to $resultFileName
$resultTag = [TagLib.Aac.File]::Create((Join-Path (Get-Item -Path ".\") $resultFileName))
$resultTag.Tag.Artists = $AudiobookArtist
$resultTag.Tag.Album = $AudiobookAlbum
$resultTag.Tag.Title= $AudiobookTitle

$images = Get-ChildItem "*.jpg"
if($images.Length -ge 1)
{
    $image =($images | Select-Object -first 1)
    Write-Host Found image $image for cover
    $resultTag.Tag.Pictures =[TagLib.Picture]::CreateFromPath( $image)
}

$resultTag.Save()
..\mp4v2-r479-windows-binaries\bin\Windows-Win32\Release\mp4chaps.exe --convert --chapter-qt $resultFileName
Write-Host Clean up...
Remove-Item $resultTmpFileName
Remove-Item $chapterFileName
Write-Host Done...