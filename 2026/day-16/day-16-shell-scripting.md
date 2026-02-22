✅ Day 16 – Shell Scripting Basics
# Day 16 – Shell Scripting Basics 🐚

Today I learned the fundamentals of Bash scripting including:
- Shebang usage
- Variables
- User input with `read`
- Conditional statements (`if-else`)
- File and service checks

## Hands on -

<img width="932" height="948" alt="image" src="https://github.com/user-attachments/assets/c9f663fa-039b-474e-ba5d-10f71ed07615" />

<img width="932" height="948" alt="image" src="https://github.com/user-attachments/assets/37d335bd-a6a3-413b-b640-491a7915f8ae" />

<img width="908" height="828" alt="image" src="https://github.com/user-attachments/assets/7bef998d-1aa9-4c7a-97a6-0c6b07d04154" />

<img width="1122" height="578" alt="image" src="https://github.com/user-attachments/assets/5e143fe2-de13-41c9-bddb-a16e01cddb7e" />

<img width="1917" height="971" alt="image" src="https://github.com/user-attachments/assets/9eaeda96-f6fc-4e68-89c2-706cf7b26815" />

---

## 📂 Scripts Created

### 1️⃣ Hello Script
**File:** [hello.sh](./hello.sh)

Prints a simple message.

**Output**
```bash

Hello, DevOps!
2️⃣ Variables Script

File: variable.sh

Demonstrates variables and difference between single vs double quotes.

Output

Hello, I am Mayank and I am a DevOps Engineer
Hello, I am $NAME and I am a $ROLE
3️⃣ User Input Script

File: greet.sh

Takes name and favourite tool from user.

Output

Enter your name: Mayank Thakur
Enter your favourite tool: terraform
Hello Mayank Thakur, your favourite tool is terraform
4️⃣ If-Else Scripts
🔹 Number Check

File: check_number.sh

Checks whether number is positive, negative or zero.

Output

Enter a number: 46
Number is Positive
🔹 File Check

File: file_check.sh

Checks whether a file exists.

Output

Enter file name: test.txt
file does not exist
5️⃣ Server Status Script

File: server_check.sh

Checks if a service is running using systemctl.

Output

Do you want to check the status? (y/n): y
ssh service is NOT running
Do you want to check the status? (y/n): n
Skipped.
🧠 What I Learned Today

#!/bin/bash tells Linux which interpreter to use

Double quotes allow variable expansion, single quotes do not

Bash conditions use [ ] and must have spaces

read -p helps take interactive input

Scripts must be executable using chmod +x

🚀 How to Run Scripts
chmod +x *.sh
./hello.sh
./variable.sh
./greet.sh
./check_number.sh
./file_check.sh
./server_check.sh
📌 Folder Structure
2026/day-16/
│── hello.sh
│── variable.sh
│── greet.sh
│── check_number.sh
│── file_check.sh
│── server_check.sh
│── README.md
🔥 Hashtags (for LinkedIn)

#90DaysOfDevOps #ShellScripting #Linux #DevOpsJourney #Bash

✅ Day 16 Completed

