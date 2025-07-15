### Swift5 port of NuShrinkItX

**Brief Outline of NuShrinkItX**

1) The application opens,  loads a ShrinkIt archive and writes its entire contents to a temporary location on the user's boot storage device. The archive is closed.

2) The user is allowed to modify the contents of the archive.

(a) Files and folders can be dragged-and-dropped from within the same window of the application or dragged-and-dropped from another window of the application. 
(b) Files and folders from Finder's desktop can be added to a ShrinkIt archive by dragging-and-dropping.
(c) Files and folders from a ShrinkIt archive can be copied to Finder's desktop by dragging-and-dropping. 
(d) NuShrinkItX can accept files and folders dragged-and-dropped from the window of another application e.g. CiderXPress.

3) Press "Command+S" to save the modified archive to disk. 

The application will re-open the original archive for writing. The entire contents of the file will be replaced with that of the edited archive.

4) If the user presses "Command+Q" to quit the program, NuShrinkItX will allow the user to save any modified (that have not been saved) archive to the user's storage device.


**SpotLight and QuickLook Plugins**

The source codes of these two plugins are written in Objective-C. Testing from within XCode are different from previous macOS versions. Before running the tests, the arguments passed must be correctly specified and there must be an ShrinkIt archive at the specified location. For example, the *Arguments Passed On Launch* for the Spotlight plugin is:

    -td2 /Users/marklim/Documents/niftylist34.shk

The output of the Spotlight plugin during testing is send the XCode's console.

The output of the QuickLook plugin is in the folder "niftylist34.shk.qlpreview" if the name of the ShrinkIt archive is "niftylist34.shk". Double-click on the file *Preview.html* to get a preview. The user can still get an output the usual way (select a ShrinkIt archive and press the space bar) if the embedded plugin is executing correctly.

Both plugins do not depend on the NuFx library since it is not necessary to access the contents of each file stored within a ShrinkIt archive.


**Support Library**

This application is built on top of the NuLib source code developed by Andy Fadden. NuShrinkItX can open any ShrinkIt archive for **editing**. ShrinkIt archives with the following file extensions are supported: SHK, SDK, BXY and BSE. However, NuLib only supports **creating** SHK archives.


**Notes**

The functionality of the Swift port is almost the same as the Objective-C version except for the saving of archives. Changes to the OS prevent Swift apps from writing .SHK files that are not in the **Data** partition of the Boot OS. For example, if the user's HDD has 2 partitions, one formatted with APFS and the other HFSPlus and the Boot OS is macOS 10.15. Suppose the user edits a SHK file which is in the HFSPlus partition, the OS does not allow the modified file to be re-opened for writing.



### System Runtime Requirements

macOS 10.10.x or later.

### Build Requirements:

XCode 11.x, Swift 5.0 or later


### Links

Apple's 

