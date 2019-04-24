# compare_trees.rb

DISCLAIMER: THIS PROGRAM IS DANGEROUS IN THE WRONG HANDS! IT IS PROVIDED AS IS. USE AT OWN RISK. BACKUP ALL FILES ON YOUR COMPUTER (OR REMOTE FILES IF USING ON NON-LOCAL FILES) BEFORE RUNNING PROGRAM. CHECK PROGRAM CODE TO ENSURE IT DOES WHAT YOU WANT.

This program compares two directories and their subdirectories recursively. If a file in the first tree exists anywhere in the second tree, the first file is optionally deleted. To be regarded the same, the file names and contents must be the same.

Usage:
```
ruby compare_trees.rb <source directory> <dest directory> [/delete]"
```

If `/delete` is provided, files in source directory are deleted if they exist somewhere in the destination directory tree. If files are deleted from a directory, the directory is deleted if it's empty. Both directories are recursed and you are NOT asked to confirm file deletion."

To try the program, omit the `/delete` switch. The files that _would_ be deleted if `/delete` were provided are listed. 

The Linux `diff` program is required, which is available on Windows too. To check if it's installed on your computer, run

```
 diff --binary --brief <file1> <file2>
```
where \<file1\> and \<file2\> are two files on your computer. If that works, you have the right `diff` program in your path.

I've used the program on Ruby 2.0 and greater on Windows and MacOS. If you don't have Ruby, see the [Ruby installation guide](https://www.ruby-lang.org/en/documentation/installation/).

I wrote this to solve a specific problem I had on a Windows PC and a MacOS computer. I had copied a directory tree to both from a third computer. Over time, the directories diverged and the files moved around. I wanted to remove all real duplicates before merging the trees together.
