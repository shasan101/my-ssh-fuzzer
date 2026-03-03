**SSH-Fuzzer** is a protocol state fuzzer which can generate Mealy machine models for SSH implementations.
Originally it was derived from the [artifact][learning-ssh-artifact] used to generate models for SSH server implementations in the publication "Model Learning and Model Checking of SSH Implementations" (link to publication PDF [here][learning-ssh]).
Since then, it was updated by Robert Lasu to support generating models for SSH clients (see thesis PDF [robert-thesis][here]).

This project consists of several components:
* the learner (ssh-learner)
* the mapper (ssh-mapper)
* results (ssh-learner/results)
* DOT trimming script (mypydot)

# Learner
The learner is implemented by a Java Eclipse project. 

To deploy, make sure you include the two provided jar files (sqlite and learnlib) in the build path (libraries tab under project properties).

The learner connects to the (python-based) mapper on localhost:8000. Make sure the mapper is running before running the learner. More on the mapper below. The input alphabet is defined in Mapper.java (generateInputAlphabet). All symbols are enabled by default, but some need to be commented out for partial learning (for example, just one layer of SSH). WordProcessor.java defines the link to the trace&response log and the non-determinism check. 

# Mapper
The mapper part is more complex. The reason for this is that is was built on top of an existing SSH implementation (Paramiko). This did ultimately involve a lost of nasty hacks to make things work. 

The core of the mapper is defined in mapper/mapper.py. This is also the command you have to run to fire up the mapper (user@desktop:mapper$ python mapper.py). You might run in some missing packages (depending on your configuration), which are easily resolved using Google.

Please read to mapper.py file to get a grip of the global interaction process with the learner. For debugging purposes, it's also possible to simply connect to the mapper using telnet (telnet localhost 8000 for a connection, and then a sequence like "reset KEXINIT KEX30 NEWKEYS"). 

The mapper/messages.py file provides a mapping to actual functions being executed as soon as a query has been received. It also provides the mapping back to textual representations.

The hacked version of paramiko can be found in manualparamiko directory. This file has been edited at countless places (use diff against the normal transport.py file in paramiko directory to find all changes). Essentially, the state machine has been removed, and the functions as noted in messages.py are executed on message arrival (for example, fuzz_disconnect on a SSH_MSG_DISCONNECT). At the end of each fuzz_ function, the read_multiple_responses is used to query and correctly handle responses. The read_response() function (used by read_multiple_responses) defines a handlers dictionary. This defines the state-changing responses and their effects.

Timing variances were a nuisance. Timing is controlled at various places:
- The time.sleep() in mapper/mapper.py (controls set timeout between runs)
- read_multiple_responses() in manualparamiko/transport.py (has both a timeout between responses and total timeout -in case of multiple responses- argument). 
- Timeout based on the type of message can be set in the individual read_multiple_responses-calls.

# Orchestration (Quick Start)

The easiest way to run SSH-Fuzzer is via Docker, which handles all dependencies for the Learner, Mapper, and the SUT (System Under Test).

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Running an Experiment
A helper script is provided to automate SSH key generation, container building, and execution.

1.  **Navigate to the scripts directory:**
    ```bash
    cd experiments/scripts
    ```
2.  **Start the learning process:**
    ```bash
    ./start_learning.sh <SUT> [ALGORITHM]
    ```

### Usage Details
The `start_learning.sh` script accepts the following parameters:

*   **`<SUT>` (Required):** The target SSH server implementation. 
    *   Options: `openssh7`, `openssh8`, `dropbear`.
*   **`[ALGORITHM]` (Optional):** Specifies a Register Automata (RA) algorithm. If provided, the fuzzer runs in RA mode.
    *   Options: `RALAMBDA`, `RASTAR`.

**Examples:**
*   **Standard Mealy Learning:** `./start_learning.sh openssh8`
*   **Register Automata Learning:** `./start_learning.sh dropbear RALAMBDA`

### Results and Outputs
Learning results (Mealy machine models, logs, and statistics) are mapped from the containers back to your host machine:

*   **Mealy (Dropbear):** `experiments/orchestration/learner_output_dropbear`
*   **Mealy (OpenSSH 7):** `experiments/orchestration/learner_output_openssh7`
*   **RA (Dropbear):** `experiments/orchestration/learner_output_ra_dropbear`
*   **RA (OpenSSH 7):** `experiments/orchestration/learner_output_openssh7_ra`

> **Note:** To modify specific Learner or Mapper arguments (e.g., timeouts, alphabet settings), edit the corresponding `.yaml` files in `experiments/orchestration/`.


# Trimming script (mypydot)
The python pydot package was altered to merge edges between the same nodes. 
Feed it a .dot file and let it do its magic. 
It needs some python packages to work with. 
A Google search will quickly determine which packages are missing.

# Useful links
- the SPIN 2017 [publication][learning-ssh] which used what would become **SSH-Fuzzer** to analyze SSH server implementations;
- Robert Lasu's [Bachelor's thesis][robert-thesis]. As part of this work, Robert extended **SSH-Fuzzer** to support SSH clients and subsequently used it to analyze implementations of Dropbear and OpenSSH. The SSH-Fuzzer version used in this work is available as a [release][robert-thesis-code];
- [**SMBugFinder**][smbugfinder], a tool which can automatically analyze for bugs the models that **SSH-Fuzzer** produces.
Also relevant are the two publications, at [ISSTA '24][smbugfinderpaper] and [NDSS '23][ndss23paper], describing **SMBugFinder** and, respectively, the technique behind it.


[learning-ssh-artifact]:https://repository.ubn.ru.nl/handle/2066/184275
[learning-ssh]:https://paulfiterau.github.io/publications/2017-SPIN.pdf
[robert-thesis]:https://www.diva-portal.org/smash/get/diva2:1795754/FULLTEXT01.pdf
[robert-thesis-code]:https://github.com/assist-project/ssh-fuzzer/releases/tag/robert-thesis
[smbugfinder]:https://github.com/assist-project/state-machine-bug-finder
[smbugfinderpaper]:https://dl.acm.org/doi/pdf/10.1145/3650212.3685310
[ndss23paper]:https://www.ndss-symposium.org/wp-content/uploads/2023/02/ndss2023_s68_paper.pdf