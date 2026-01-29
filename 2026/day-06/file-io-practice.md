#  Day 06 – Linux Fundamentals: Read and Write Text Files

## Files Created
- notes.txt
- file-io-practice.md

## Commands Practiced

- `touch notes.txt`  
  Created an empty file.

- `echo "Line 1" > notes.txt`  
  Wrote content using output redirection.

- `echo "Line 2" >> notes.txt`  
  Appended content to the file.

- `echo "Line 3" | tee -a notes.txt`  
  Displayed output and appended it simultaneously.

- `cat notes.txt`  
  Read the full file.

- `head -n 2 notes.txt`  
  Read the first two lines.

- `tail -n 2 notes.txt`  
  Read the last two lines.

## Learning
File read/write operations are essential for logs, configs, and automation in DevOps.

