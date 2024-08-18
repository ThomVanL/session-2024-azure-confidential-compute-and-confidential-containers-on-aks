# Unencrypted Memory Demo

This is a super simple demo to show that when you're running an application, there are tools that make it (sometimes trivially easy) to pull values directly from memory. It’s a friendly reminder that any sensitive information in memory is at risk if left unprotected... Which is something that Azure Confidential Computing addresses by encrypting memory regions.

## Pre-requisites

Before you start, ensure you have the following:

- **Windows Virtual Machine:** Any Windows-based VM will do.

Additionally, you'll need some software installed on the Windows VM:

- **Sysinternals Procdump:** [Download here](https://learn.microsoft.com/en-us/sysinternals/downloads/procdump)
- **WinDbg:** [Download here](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/)

## Demo Steps

### 1. Set Up the Environment

- **Launch Notepad:** Open a single instance of Notepad and type in some text. **Do not save** the file—this is key to demonstrating that whatever is sitting in memory is potentially at risk.

```plaintext
This is a super secret message!
```

### 2. Dump the Process Memory

- **Open PowerShell:** Launch a PowerShell window on your VM.
- **Run Procdump:** Execute the following command to dump the memory contents of the Notepad process:

```powershell
.\procdump64 -ma Notepad
```

The `-ma` flag ensures Procdump creates a "full" dump file that includes:
- All memory (Image, Mapped, and Private)
- All metadata (Process, Thread, Module, Handle, Address Space, etc.)

This will generate a file named something like `notepad.exe.<timestamp>.dmp`.

### 3. Analyze the Dump with WinDbg

- **Open the Dump File:** Launch WinDbg, then select **File > Start Debugging > Open Dump File** and choose the dump file you just created.
- **Search for Memory Content:** Use the Address extension to search for Unicode strings in the heap. Enter the following command in WinDbg:

```cmd
!address /f:Heap /c:"s -su %1 %2"
```

**What this does:**
- **[`!address extension`](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-address)** Shows information about the memory used by the process.
- **`/f:Heap` Filter:** Narrows the output to the heap region (because it’s unlikely the unsaved text is on the stack).
- **`-c:"s -su %1 %2"`:** Executes a command for each heap region:
    - **[`s -su`](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/s--search-memory-):** Searches for all printable Unicode strings.
    - **`%1` and `%2`:** Represent the start and end (plus one) addresses of each region.

- **Verify the Data:** Scroll through the output or search for parts of the text you typed in Notepad. You should be able to see your message!