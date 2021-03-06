<?php
// Copyright 2018 SugarCRM Inc.  Licensed by SugarCRM under the Apache 2.0 license.
namespace Sugarcrm\ProfessorM;

use function array_push;
use const DIRECTORY_SEPARATOR;
use function file_get_contents;
use function getcwd;
use function strlen;

/**
 * Class PackageGenerator
 * @package Sugarcrm\ProfessorM
 */
class PackageGenerator
{
    protected $cwd;

    public function __construct(){
        $this -> cwd = getcwd();
    }

    /*
     * $cwd defaults to the current working directory so you should only need to use this function if you are testing
     */
    public function setCwd($pathOfWorkingDirectory){
        $this -> cwd = $pathOfWorkingDirectory;
    }

    public function shouldIncludeFileInZip($fileRelative)
    {
        /*
         * We want to exclude files in the following directories:
         *    custom/application/Ext
         *    custom/modules/.../Ext
         * The regular expressions allow for file paths with forward or backward slashes */
        if(preg_match('/.*custom[\/\\\]application[\/\\\]Ext[\/\\\].*/', $fileRelative) or
            preg_match('/.*custom[\/\\\]modules[\/\\\].+[\/\\\]Ext[\/\\\].*/', $fileRelative)){
            return false;
        }
        // Fix for MacOS, Git submodules
        if (preg_match('/\.(DS_Store|git)$/', $fileRelative))
        {
            return false;
        }
        return true;
    }


    /*
     * Checks if the file path is too long and should be excluded from Windows builds
     */
    public function shouldIncludeFileInWindowsZip($fileRelative, $lengthOfWindowsSugarDirectoryPath)
    {
        # During install, Sugar puts files in [SugarDirectory]/cache/upgrades/temp/xxxx.tmp/relativefilepath
        # Windows allows 259 characters in the file path plus the ending null character
        # From manual testing, discovered 258 is the max file path allowed
        if($lengthOfWindowsSugarDirectoryPath + strlen("/cache/upgrades/temp/xxxx.tmp/") + strlen($fileRelative) > 258){
            return false;
        }
        return true;
    }

    /*
     * Get the version that should be used for the zip.  If a version
     * is not passed as a param, the function checks for a file named
     * "version" and gets the version out of the file.
     */
    public function getVersion($versionPassedToScript){
        if (empty($versionPassedToScript)) {
            $pathToVersionFile = $this -> cwd . DIRECTORY_SEPARATOR . "version";
            if (file_exists($pathToVersionFile)) {
                return file_get_contents($pathToVersionFile);
            }
        }
        return $versionPassedToScript;
    }

    /*
     * Returns the relative file path for the zip file that will be created.
     * @throws \Exception if $version is empty.
     * Will make a releases directory if one does not already exists.
     */
    public function getZipFilePath($version, $packageID, $command){
        if (empty($version)){
            throw new \Exception("Use $command [version]\n");
        }

        $id = "{$packageID}-{$version}";

        $directory = "releases";
        if(!is_dir($directory)){
            mkdir($directory);
        }

        $zipFile = $directory . DIRECTORY_SEPARATOR . "sugarcrm-{$id}.zip";
        return $zipFile;
    }

    /**
     * Iterate over the files located in the $srcDirectory and return an array that contains a
     * array of files to include in the zip and an array of files to exclude from the zip
     *
     * @param $srcDirectory
     * @return array of arrays:
     *   filesToInclude: list of files to include in the zip
     *   filesToExclude: list of files that should not be included in the zip
     *   filesToExcludeWindows: list of files that should not be included in the zip because they require manual installation
     *                          on Windows. This list will be empty if this is NOT a Windows build.
     */
    public function getFileArraysForZip($srcDirectory, $isWindowsBuild, $lengthOfWindowsSugarDirectoryPath)
    {
        $filesToInclude = array();
        $filesToExclude = array();
        $filesToExcludeWindows = array();

        $basePath = $this->cwd . DIRECTORY_SEPARATOR . $srcDirectory;

        $files = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($basePath, \RecursiveDirectoryIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::LEAVES_ONLY
        );

        foreach ($files as $name => $file) {
            if ($file->isFile()) {

                $fileReal = $file->getPath() . DIRECTORY_SEPARATOR . $file->getBasename();
                $fileRelative = $srcDirectory . str_replace($basePath, '', $fileReal);
                $fileArray = array("fileReal" => $fileReal, "fileRelative" => $fileRelative);

                if ($this->shouldIncludeFileInZip($fileRelative)) {
                    if ($isWindowsBuild && !$this->shouldIncludeFileInWindowsZip($fileRelative, $lengthOfWindowsSugarDirectoryPath)){
                        array_push($filesToExcludeWindows, $fileArray);
                        continue;
                    }
                    array_push($filesToInclude, $fileArray);
                } else {
                    array_push($filesToExclude, $fileArray);
                }

            }
        }
        return array(
            "filesToInclude" => $filesToInclude,
            "filesToExclude" => $filesToExclude,
            "filesToExcludeWindows" => $filesToExcludeWindows
        );

    }

    /**
     * Creates and opens a new zip archive
     *
     * @param $version
     * @param $packageID
     * @param $command
     * @return \ZipArchive
     * @throws \Exception if a zip file with the same name already exists
     */
    public function openZip($version, $packageID, $command){
        $zipFile = $this -> getZipFilePath($version, $packageID, $command);

        if (file_exists($zipFile)) {
            throw new \Exception("Error:  Release $zipFile already exists, so a new zip was not created. To generate a"
                . " new zip, either delete the"
                . " existing zip file or update the version number in the version file AND then run the script to build the"
                . " module again. \n");
        }

        echo "Creating {$zipFile} ... \n";
        $zip = new \ZipArchive();
        $zip->open($zipFile, \ZipArchive::CREATE);
        return $zip;
    }

    public function closeZip($zip){
        $filename = basename($zip -> filename);
        $zip->close();
        echo "Done creating $filename\n\n";
        return $zip;
    }

    /*
     * Adds the files listed in $filesToInclude to the $zip
     */
    public function addFilesToZip($zip, $filesToInclude){
        foreach($filesToInclude as $file) {
            echo " [*] " . $file['fileRelative'] . "\n";
            $zip->addFile($file['fileReal'], $file['fileRelative']);
        }
        return $zip;
    }

    /*
     * Adds the files listed in $filesToInclude to the zip in indexed directories
     * Also adds a text file that describes where the files should be manually installed
     */
    public function addFilesToWindowsManualInstallZip($zip, $filesToInclude, $srcDirectory){
        $readmeFile = 'ProfMForWindowsReadme.txt';
        $readmeHandle = fopen($readmeFile, 'w') or die ("Unable to open file: " . $readmeFile);
        $newFileText = "The following is a list of files that should be manually installed if you use the Professor M " .
            "package for Windows.  After manual installation, run Quick Repair & Rebuild. " .
            "See https://github.com/sugarcrm/school/blob/master/README.md for more details.\n\n";
        fwrite($readmeHandle, $newFileText);


        foreach($filesToInclude as $index => $file) {
            echo " [*] " . $index . "/" . basename($file['fileReal']) . "\n";
            fwrite($readmeHandle,
                " [*] " . $index . "/" . basename($file['fileReal']) . "\n" .
                "     should be manually installed at \n" .
                "     [YourSugarDirectory]/" . preg_replace('/^' . $srcDirectory .'[\/\\\](.*)/', '$1', $file['fileRelative']) . "\n\n");
            $zip->addFile($file['fileReal'], $index . "/" . basename($file['fileReal']));
        }

        fclose($readmeHandle);
        echo " [*] " . $readmeFile . "\n";
        $zip->addFile($readmeFile, $readmeFile);

        return $zip;
    }

    /**
     * @param $filesToInclude
     * @param $installdefs
     * @param $srcDirectory
     * @return mixed
     */
    public function addFilesToInstalldefs($filesToInclude, $installdefs, $srcDirectory){
        foreach($filesToInclude as $file) {
            $installdefs['copy'][] = array(
                'from' => '<basepath>/' . $file['fileRelative'],
                'to' => preg_replace('/^' . $srcDirectory .'[\/\\\](.*)/', '$1', $file['fileRelative']),
            );
        }
        return $installdefs;
    }

    /*
     * Outputs a list of files that were excluded from the zip
     */
    public function echoExcludedFiles($filesToExclude){
        if (!empty($filesToExclude)){
            echo "The following files were excluded from the zip: \n";
            foreach($filesToExclude as $file) {
                echo " [*] " . $file["fileRelative"] . "\n";
            }
        }
    }

    /*
     * Creates manifest.php where the content of the file is made up of the $manifestContent and $installdefs.
     * The resulting manifest.php file is placed in the $zip.
     */
    public function generateManifest($manifestContent, $installdefs, $zip){
        $manifestContent = sprintf(
            "<?php\n\$manifest = %s;\n\$installdefs = %s;\n",
            var_export($manifestContent, true),
            var_export($installdefs, true)
        );
        $zip->addFromString('manifest.php', $manifestContent);
        return $zip;
    }

    /*
     * Creates the zip for the Module Loadable Package
     */
    public function generateZip($version, $packageID, $command, $srcDirectory, $manifestContent, $installdefs,
                                $isWindowsBuild, $lengthOfWindowsSugarDirectoryPath){

        if ($isWindowsBuild){
            $version = $version . "-windows";
        } else {
            $version = $version . "-standard";
        }

        $zip = $this -> openZip($version, $packageID, $command);

        $arrayOfFiles = $this -> getFileArraysForZip($srcDirectory, $isWindowsBuild, $lengthOfWindowsSugarDirectoryPath);
        $filesToInclude = $arrayOfFiles["filesToInclude"];
        $filesToExclude = $arrayOfFiles["filesToExclude"];
        $filesToExcludeWindows = $arrayOfFiles["filesToExcludeWindows"];

        $zip = $this -> addFilesToZip($zip, $filesToInclude);
        $installdefs = $this -> addFilesToInstalldefs($filesToInclude, $installdefs, $srcDirectory);

        $zip = $this -> generateManifest($manifestContent, $installdefs, $zip);
        $zip = $this -> closeZip($zip);

        $this -> echoExcludedFiles($filesToExclude);

        if ($isWindowsBuild){
            $zip = $this -> openZip($version . "-manual-install", $packageID, $command);
            $zip = $this -> addFilesToWindowsManualInstallZip($zip, $filesToExcludeWindows, $srcDirectory);
            $zip = $this -> closeZip($zip);
        }

        return $zip;
    }
}
