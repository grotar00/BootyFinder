## BootyFinder

Compare two image collections by hash sums of their content. Unique images will be displayed as a grid of previews and may be duplicated to a separate folder.

###### How to use
Default scan path is set to application's directory.

To create a *REFERENCE* list with MD5 of your collection's files, enter path to a main folder in a text field and press **NEW** button on the right.
File "__HASHES_NEW.txt" will be created in application directory. Rename it to "__HASHES.txt" to use as main reference during scan.
To complete "__HASHES_NEW.txt" with new entries, press **ADD* button. Existing entries will be ignored.

To start a new *SCAN*, enter path to a main folder in a text field and press **SCAN**. Please note that application may **stop responding** when processing more than 500 files. It may take more than a minute but application will be terminated if anything pressed during this state.
If result is empty: referenced collection is identical or more complete than matching one.
If less than 300 unique files found: press **SAVE THUMBNAILS** to create window screenshot with previews or **EXPORT** to copy listed files in new folder within application directory.
