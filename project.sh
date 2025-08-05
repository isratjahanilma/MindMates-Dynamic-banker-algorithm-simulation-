GNU nano 8.4                                                                                                                                                                                                                                                                                                                                                                                                                       project7.sh                                                                                                                                                                                                                                                                                                                                                                                                                                 
#!/bin/bash

# ======= GLOBALS =======
declare -A alloc max need finish
available=()
n=0
m=0
logfile="banker_log.txt"
timeline=()

# === Stats Counters ===
safe_checks=0
deadlock_count=0
recovery_count=0
completed_processes=0

# ======= COLORS =======
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ======= SPLASH SCREEN =======
welcome_splash() {
    clear
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   🧠 WELCOME TO Deadlock Defender: ${NC}"
    echo -e "${CYAN}   Dynamic Banker's Algorithm in Bash   ${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${YELLOW}   Built for Real-Time Resource Safety Analysis${NC}"
    echo -e "${CYAN}Log File:${NC} ${logfile}"
    echo -e "\nPress Enter to continue..."
    read
}

# ======= INPUT =======
read_input() {
    echo -e "${CYAN}Enter number of processes:${NC}"
    read n
    echo -e "${CYAN}Enter number of resource types:${NC}"
    read m

    echo -e "${CYAN}Enter Allocation Matrix:${NC}"
    for ((i = 0; i < n; i++)); do
        echo -n "P$i: "
        read -a row
        for ((j = 0; j < m; j++)); do
            alloc[$i,$j]=${row[j]}
        done
    done

    echo -e "${CYAN}Enter Maximum Matrix:${NC}"
    for ((i = 0; i < n; i++)); do
        echo -n "P$i: "
        read -a row
        for ((j = 0; j < m; j++)); do
            max[$i,$j]=${row[j]}
        done
    done

    echo -e "${CYAN}Enter Available Resources:${NC}"
    read -a available

    for ((i = 0; i < n; i++)); do
        for ((j = 0; j < m; j++)); do
            need[$i,$j]=$(( max[$i,$j] - alloc[$i,$j] ))
        done
    done
}

# ======= VIEW STATE =======
# ======= VIEW STATE =======
display_state() {
    echo -e "\n${CYAN}🔎 Current System State:${NC}"
    printf "%s\n" "╔════════════════════════════════════════════════════════╗"
    printf "║ %-8s ║ %-10s ║ %-10s ║ %-10s ║\n" "Process" "Allocation" "Max" "Need"
    printf "%s\n" "╠════════════════════════════════════════════════════════╣"
    for ((i = 0; i < n; i++)); do
        alloc_str=""; max_str=""; need_str=""
        for ((j = 0; j < m; j++)); do alloc_str+="${alloc[$i,$j]} "; done
        for ((j = 0; j < m; j++)); do max_str+="${max[$i,$j]} "; done
        for ((j = 0; j < m; j++)); do need_str+="${need[$i,$j]} "; done
        printf "║ %-8s ║ %-10s ║ %-10s ║ %-10s ║\n" "P$i" "$alloc_str" "$max_str" "$need_str"
    done
    printf "%s\n" "╚════════════════════════════════════════════════════════╝"
    echo -e "Available: ${available[*]}"
}


check_safe_state() {
    ((safe_checks++))

    # Helper to log both to console and logfile
    log_echo() {
        echo -e "$1" | tee -a "$logfile"
    }

    log_echo "\n=== SAFETY CHECK START $(date) ==="
    local work=("${available[@]}")
    local local_finish=()
    timeline=()
    for ((i = 0; i < n; i++)); do local_finish[$i]=0; done
    count=0

    log_echo "${CYAN}🌀 Checking Safety Step-by-Step...${NC}"
    while [ $count -lt $n ]; do
        found=0
        for ((i = 0; i < n; i++)); do
            if [ ${local_finish[$i]} -eq 0 ]; then
                log_echo "${YELLOW}Checking Process P$i:${NC}"
                can_allocate=1
                for ((j = 0; j < m; j++)); do
                    if [ ${need[$i,$j]} -gt ${work[$j]} ]; then
                        log_echo " Need: ${need[$i,$j]} <= Available: ${work[$j]} ? ${RED}No${NC}"
                        can_allocate=0
                        break
                    else
                        log_echo " Need: ${need[$i,$j]} <= Available: ${work[$j]} ? ${GREEN}Yes${NC}"
                    fi
                done

                if [ $can_allocate -eq 1 ]; then
                    log_echo "${GREEN}✔ Process P$i can execute. Releasing its resources back to available.${NC}"
                    for ((j = 0; j < m; j++)); do
                        work[$j]=$((work[$j] + alloc[$i,$j]))
                    done
                    local_finish[$i]=1
                    timeline+=("P$i")
                    ((count++))
                    ((completed_processes++)) 
                    found=1
                else
                    ((deadlock_count++))
                    log_echo "${RED}✘ Process P$i cannot execute now due to insufficient resources.${NC}"
                fi
                log_echo ""
                sleep 1
            fi
        done
        if [ $found -eq 0 ]; then
            log_echo "${RED}⚠ Deadlock detected! No further processes can proceed.${NC}"
            break
        fi
    done

    if [ $count -eq $n ]; then
        log_echo "${GREEN}✅ System is in a safe state! Safe sequence:${NC} ${timeline[*]}"
        echo "[SAFE] Sequence: ${timeline[*]}" >> "$logfile"
    else
        log_echo "${RED}❌ System is NOT in a safe state! Deadlock detected involving these processes:${NC}"
        # List processes not finished yet
        for ((i = 0; i < n; i++)); do
            if [ ${local_finish[$i]} -eq 0 ]; then
                log_echo "${RED} - Process P$i${NC}"
            fi
        done
        echo "[UNSAFE] Deadlock detected involving processes: ${timeline[*]}" >> "$logfile"
        recover_deadlock "${local_finish[@]}"
    fi

    log_echo "=== SAFETY CHECK END $(date) ==="
}

recover_deadlock() {
    local -a stuck_processes=()
    local finish=("$@")
    for ((i = 0; i < n; i++)); do
        if [ ${finish[$i]} -eq 0 ]; then
            stuck_processes+=($i)
        fi
    done

    echo -e "${CYAN}🛠 Deadlock Recovery Options (Automated):${NC}"
    echo "1. Auto-Terminate all stuck processes"
    echo "2. Auto-Preempt from highest-alloc process"
    echo "3. Auto-Rollback highest-alloc process"
    echo "4. Kill greedy one (highest total allocation)"
    echo "5. Return to Main Menu"

    read -p "Choose a recovery option (1-5): " choice

    case $choice in
        1) auto_terminate_all "${stuck_processes[@]}" ;;
        2) auto_preempt_highest ;;
        3) auto_rollback_highest ;;
        4) auto_kill_greedy ;;
        5) 
            echo -e "${YELLOW}↩ Returning to main menu...${NC}" 
            return
            ;;
        *) 
            echo -e "${RED}Invalid choice. Defaulting to option 1.${NC}" 
            auto_terminate_all "${stuck_processes[@]}"
            ;;
    esac

    echo -e "${YELLOW}🔁 Re-checking system safety after recovery...${NC}"
    check_safe_state
    ((recovery_count++))
}
auto_terminate_all() {
    local victims=("$@")
    echo -e "${RED}🚨 Terminating all stuck processes to resolve deadlock...${NC}"
    for pid in "${victims[@]}"; do
        echo -e "❌ Process P$pid is stuck and will be terminated to free resources."
        for ((j = 0; j < m; j++)); do
            available[$j]=$((available[$j] + alloc[$pid,$j]))
            alloc[$pid,$j]=0
            need[$pid,$j]=0
        done
    done
    echo -e "${GREEN}✔ All stuck processes terminated. Resources reclaimed.${NC}"
}

auto_preempt_highest() {
    local max_alloc=-1
    local target_pid=-1
    for ((i = 0; i < n; i++)); do
        total=0
        for ((j = 0; j < m; j++)); do
            total=$((total + alloc[$i,$j]))
        done
        if (( total > max_alloc )); then
            max_alloc=$total
            target_pid=$i
        fi
    done

    echo -e "${RED}⚠ Preempting all resources from P$target_pid (greediest process).${NC}"
    for ((j = 0; j < m; j++)); do
        available[$j]=$((available[$j] + alloc[$target_pid,$j]))
        need[$target_pid,$j]=$((need[$target_pid,$j] + alloc[$target_pid,$j]))
        alloc[$target_pid,$j]=0
    done
    echo -e "${GREEN}✔ Resources successfully preempted from P$target_pid.${NC}"
}

auto_rollback_highest() {
    local max_alloc=-1
    local target_pid=-1
    for ((i = 0; i < n; i++)); do
        total=0
        for ((j = 0; j < m; j++)); do
            total=$((total + alloc[$i,$j]))
        done
        if (( total > max_alloc )); then
            max_alloc=$total
            target_pid=$i
        fi
    done

    echo -e "${CYAN}🔁 Rolling back P$target_pid to safe state...${NC}"
    for ((j = 0; j < m; j++)); do
        available[$j]=$((available[$j] + alloc[$target_pid,$j]))
        alloc[$target_pid,$j]=0
        need[$target_pid,$j]=${max[$target_pid,$j]}
    done
    echo -e "${GREEN}✔ Process P$target_pid rolled back.${NC}"
}

auto_kill_greedy() {
    local max_alloc=-1
    local target_pid=-1
    for ((i = 0; i < n; i++)); do
        total=0
        for ((j = 0; j < m; j++)); do
            total=$((total + alloc[$i,$j]))
        done
        if (( total > max_alloc )); then
            max_alloc=$total
            target_pid=$i
        fi
    done

    echo -e "${RED}💀 Killing greedy process P$target_pid to recover resources.${NC}"
    for ((j = 0; j < m; j++)); do
        available[$j]=$((available[$j] + alloc[$target_pid,$j]))
        alloc[$target_pid,$j]=0
        need[$target_pid,$j]=0
    done
    echo -e "${GREEN}✔ Greedy process P$target_pid killed. Deadlock partially resolved.${NC}"
}




# ======= REQUEST RESOURCES =======
request_resources() {
    read -p "Enter Process ID to request resources for (e.g. 1): " pid
    read -p "Enter resource request (space-separated): " -a req

    for ((j = 0; j < m; j++)); do
        if [ ${req[j]} -gt ${need[$pid,$j]} ]; then
            echo -e "${RED}❌ Request exceeds declared need!${NC}"
            return
        fi
        if [ ${req[j]} -gt ${available[$j]} ]; then
            echo -e "${RED}❌ Not enough available resources!${NC}"
            return
        fi
    done

    for ((j = 0; j < m; j++)); do
        available[$j]=$((available[$j] - req[j]))
        alloc[$pid,$j]=$((alloc[$pid,$j] + req[j]))
        need[$pid,$j]=$((need[$pid,$j] - req[j]))
    done
    echo -e "${GREEN}✔ Request granted. Resources allocated to P$pid.${NC}"
    check_safe_state


}

# ======= RELEASE RESOURCES =======
release_resources() {
    read -p "Enter Process ID to release resources from (e.g. 1): " pid
    read -p "Enter resource release (space-separated): " -a rel
    for ((j = 0; j < m; j++)); do
        if [ ${rel[j]} -gt ${alloc[$pid,$j]} ]; then
            echo -e "${RED}❌ P$pid does not have that many units of resource $j allocated!${NC}"bar            return
        fi
    done

    for ((j = 0; j < m; j++)); do
        available[$j]=$((available[$j] + rel[j]))
        alloc[$pid,$j]=$((alloc[$pid,$j] - rel[j]))
        need[$pid,$j]=$((need[$pid,$j] + rel[j]))
    done
    echo -e "${GREEN}✔ Resources released from P$pid.${NC}"
    check_safe_state
}
# ======= PROCESS PROGRESS VISUALIZATION (OPTION 5) =======
show_progress_bar() {
    echo -e "\n${CYAN}📊 Process Progress Visualization:${NC}"
    for ((i = 0; i < n; i++)); do
        total=0
        current=0
        resource_use=0
        total_resources=0

        echo -e "\n🔹 Process P$i:"

        for ((j = 0; j < m; j++)); do
            alloc_val=${alloc[$i,$j]}
            max_val=${max[$i,$j]}
            avail_val=${available[$j]}

            total=$((total + max_val))
            current=$((current + alloc_val))
            resource_use=$((resource_use + alloc_val))

            # Per-resource percentage
            res_percent=$(( max_val == 0 ? 0 : (100 * alloc_val / max_val) ))

            echo -e "   🔐 Resource R$j: ${alloc_val}/${max_val} (${res_percent}%) used"
        done

        # Calculate total available system-wide (available + allocated)
        for ((j = 0; j < m; j++)); do
            total_resources=$((total_resources + available[$j]))
        done
        total_resources=$((total_resources + resource_use))

        # Progress and resource usage percentages
        percent=$(( total == 0 ? 100 : (100 * current / total) ))
        usage=$(( total_resources == 0 ? 0 : (100 * resource_use / total_resources) ))

        # Generate progress bar
        bar=""
        for ((k = 0; k < percent / 10; k++)); do bar+="#"; done
        for ((k = ${#bar}; k < 10; k++)); do bar+="."; done

        echo -e "   📈 Total Progress: [${bar}] ${percent}% complete"
        echo -e "   📦 Resource Usage: ${usage}% of total system resources"
    done
}




# ======= STATS REPORT (OPTION 6) =======
show_stats() {
    echo -e "\n${CYAN}📈 Simulation Statistics Report:${NC}"
    echo -e "${YELLOW}──────────────────────────────────────${NC}"
    printf "%-25s %d\n" "Safe State Checks:" $safe_checks
    printf "%-25s %d\n" "Deadlocks Detected:" $deadlock_count
    printf "%-25s %d\n" "Recoveries Performed:" $recovery_count
    printf "%-25s %d\n" "Completed Processes:" $completed_processes
    echo -e "${YELLOW}──────────────────────────────────────${NC}"
}
export_html_report() {
    report_file="banker_report_$(date +%Y%m%d_%H%M%S).html"
    {
        echo "<html><head><title>Deadlock Defender Report</title>"
        echo "<style>
            body { font-family: Arial, sans-serif; padding: 20px; }
            h1, h2 { color: #2A8B8B; }
            pre { background: #f4f4f4; padding: 10px; border: 1px solid #ccc; white-space: pre-wrap; }
            ul { line-height: 1.6; }
        </style>"
        echo "</head><body>"

        echo "<h1>📄 Banker's Algorithm Simulation Report</h1>"
        echo "<p><strong>Date:</strong> $(date)</p>"

        echo "<h2>🌀 Execution Timeline</h2>"
        echo "<p><strong>Safe Sequence:</strong> ${timeline[*]}</p>"

        echo "<h2>📊 System Matrices</h2>"

        echo "<h3>Allocation Matrix</h3><pre>"
        for ((i = 0; i < n; i++)); do
            echo -n "P$i: "
            for ((j = 0; j < m; j++)); do
                echo -n "${alloc[$i,$j]} "
            done
            echo
        done
        echo "</pre>"

        echo "<h3>Maximum Matrix</h3><pre>"
        for ((i = 0; i < n; i++)); do
            echo -n "P$i: "
            for ((j = 0; j < m; j++)); do
                echo -n "${max[$i,$j]} "
            done
            echo
        done
        echo "</pre>"

        echo "<h3>Need Matrix</h3><pre>"
        for ((i = 0; i < n; i++)); do
            echo -n "P$i: "
            for ((j = 0; j < m; j++)); do
                echo -n "${need[$i,$j]} "
            done
            echo
        done
        echo "</pre>"

        echo "<h3>Available Resources</h3><p>${available[*]}</p>"

        echo "<h2>⚠ Deadlock & Recovery Summary</h2>"
        echo "<ul>"
        echo "<li>Total Safe Checks: <strong>$safe_checks</strong></li>"
        echo "<li>Total Deadlocks Detected: <strong>$deadlock_count</strong></li>"
        echo "<li>Total Recoveries Performed: <strong>$recovery_count</strong></li>"
        echo "<li>Total Completed Processes: <strong>$completed_processes</strong></li>"
        echo "</ul>"

        echo "<h2>📝 Latest Safety Check Details</h2><pre>"
        # Extract the last safety check block from logfile
        sed -n '/=== SAFETY CHECK START/,/=== SAFETY CHECK END/p' "$logfile" | tail -n 1000
        echo "</pre>"

        echo "<p><em>Report generated by <strong>Deadlock Defender</strong> – Dynamic Banker’s Algorithm Simulator in Bash</em></p>"

        echo "</body></html>"
    } > "$report_file"

    echo -e "${GREEN}✔ HTML report exported to $report_file${NC}"

    # Try to auto-open in browser (Linux)
    if command -v xdg-open &> /dev/null; then
        xdg-open "$report_file"
    fi
}
generate_random_input() {
    echo -e "${CYAN}Generating a random input scenario...${NC}"
    
    n=$((RANDOM % 3 + 3))  # 3 to 5 processes
    m=$((RANDOM % 2 + 2))  # 2 to 3 resource types

    echo -e "Processes: $n, Resources: $m"

    for ((i = 0; i < n; i++)); do
        for ((j = 0; j < m; j++)); do
            alloc[$i,$j]=$((RANDOM % 4))  # Random 0–3
        done
    done

    for ((i = 0; i < n; i++)); do
        for ((j = 0; j < m; j++)); do
            max[$i,$j]=$((alloc[$i,$j] + RANDOM % 3 + 1))  # Max >= Alloc
        done
    done
    for ((j = 0; j < m; j++)); do
        available[$j]=$((RANDOM % 5 + 1))  # Available between 1–5
    done
 for ((i = 0; i < n; i++)); do
        for ((j = 0; j < m; j++)); do
            need[$i,$j]=$(( max[$i,$j] - alloc[$i,$j] ))
        done
    done

    echo -e "${GREEN}✔ Random scenario generated.${NC}"
}

generate_lessons_and_quiz_html() {
    html_file="lessons_and_quiz_$(date +%Y%m%d_%H%M%S).html"
    {
        echo "<!DOCTYPE html>"
        echo "<html lang='en'><head><meta charset='UTF-8'><title>Deadlock Lessons & Quiz</title>"
        echo "<style>
            body { font-family: Arial, sans-serif; padding: 20px; background: #fefefe; color: #222; max-width: 900px; margin: auto; }
            h1, h2, h3 { color: #007070; }
            p, ul { line-height: 1.6; }
            pre { background: #f4f4f4; padding: 10px; border: 1px solid #ccc; white-space: pre-wrap; }
            .quiz-level { margin-top: 40px; border: 1px solid #007070; padding: 20px; border-radius: 8px; }
            .question { margin-bottom: 15px; }
            label { display: block; margin: 5px 0; cursor: pointer; }
            button { margin-top: 10px; padding: 8px 14px; background: #007070; color: white; border: none; border-radius: 4px; cursor: pointer; }
            button:hover { background: #005050; }
            .result { margin-top: 15px; font-weight: bold; color: #007070; }
            .hidden { display: none; }
        </style>"
        echo "</head><body>"

        echo "<h1>📚 Deadlock and Banker's Algorithm – Lessons & Interactive Quiz</h1>"

        echo "<h2>1. What is Deadlock?</h2>"
        echo "<p>Deadlock is a state in which every process is waiting for a resource held by another, forming a cycle of waiting that prevents all involved processes from proceeding.The Four Conditions:
<ul><li>1. Mutual Exclusion:
At least one resource must be held in a non-sharable mode, meaning only one process can use it at a time.</li> 
<li>2. Hold and Wait:
A process must be holding at least one resource and waiting to acquire additional resources held by other processes.</li> 
<li>3. No Preemption:
Resources cannot be forcibly taken away from a process holding them; a process can only release a resource voluntarily. </li>
<li>4. Circular Wait:
A circular chain of processes exists, where each process is waiting for a resource held by the next process in the chain.</li> </p>"

        echo "<h2>2. Banker's Algorithm</h2>"
        echo "<p>Banker's Algorithm is used to avoid deadlock by simulating resource allocation for safety. It checks whether granting a resource request leads to a safe state.<ul><li>Key Components and Principles:</li>
Resource Allocation: Processes declare their maximum resource needs in advance.
Safety Check: Before granting a resource request, the algorithm simulates the allocation and checks if the resulting system state is "safe." A safe state is one where there exists a sequence of processes that can complete their execution, even if all processes request their maximum remaining resources.
Deadlock Avoidance: If granting a request would lead to an unsafe state, the request is denied, and the process must wait. This prevents the system from entering a deadlock.</p>"

        echo "<h2>3. Deadlock Detection</h2>"
        echo "<p>Detection involves checking for cycles or unresolvable waits in the system resource graph.</p>"

        echo "<h2>4. Recovery Techniques</h2>"
        echo "<ul>
            <li>Terminate all deadlocked processes</li>
            <li>Terminate one at a time until deadlock resolves</li>
            <li>Preempt resources and roll back</li>
        </ul>"

        echo "<hr><div id='quiz-container'>"

        # Actual quiz content
        declare -a questions=(
            "Q1: What causes a deadlock?"
            "Q2: Which is NOT a deadlock recovery method?"
            "Q3: Which condition is necessary for deadlock?"
            "Q4: What is the main goal of the Banker's Algorithm?"
            "Q5: How is the 'Need' matrix calculated?"
            "Q6: What does a 'safe state' mean?"
            "Q7: Which recovery strategy may cause starvation?"
            "Q8: What is a common symptom of deadlock?"
            "Q9: Which matrix shows remaining needed resources?"
            "Q10: Deadlock needs mutual exclusion. (T/F)"
            "Q11: Banker's algorithm works without knowing maximum demands. (T/F)"
            "Q12: Killing all processes is the safest way to recover from deadlock. (T/F)"
        )

        declare -a options_a=(
            "Syntax errors"
            "Starvation"
            "Mutual exclusion"
            "To maximize resource use"
            "Need = Allocation - Max"
            "All processes will eventually finish"
            "Killing one process at a time"
            "Increased CPU usage"
            "Allocation matrix"
            "True"
            "True"
            "True"
        )
        declare -a options_b=(
            "Resource waiting cycle"
            "Process killing"
            "Starvation"
            "To avoid deadlock"
            "Need = Max - Allocation"
            "Deadlock is impossible"
            "Killing all at once"
            "Processes finish faster"
            "Max matrix"
            "False"
            "False"
            "False"
        )
        declare -a options_c=(
            "Infinite loop"
            "Rollback"
            "Priority scheduling"
            "To detect deadlocks"
            "Max + Allocation"
            "All resource requests are granted"
            "Preemption with rollback"
            "No I/O operations"
            "Need matrix"
            "" "" ""
        )
        declare -a correct_answers=("b" "a" "c" "b" "b" "b" "c" "a" "c" "t" "f" "f")

        level=1
        for i in "${!questions[@]}"; do
            qid=$((i+1))
            [[ $((i % 3)) == 0 ]] && echo "<div class='quiz-level hidden' id='level$level'><h3>Level $level</h3><form>"
            echo "<div class='question'>"
            echo "<p>${questions[$i]}</p>"
            if [[ $qid -le 9 ]]; then
                echo "<label><input type='radio' name='q$qid' value='a'> a) ${options_a[$i]}</label>"
                echo "<label><input type='radio' name='q$qid' value='b'> b) ${options_b[$i]}</label>"
                echo "<label><input type='radio' name='q$qid' value='c'> c) ${options_c[$i]}</label>"
            else
                echo "<label><input type='radio' name='q$qid' value='t'> True</label>"
                echo "<label><input type='radio' name='q$qid' value='f'> False</label>"
            fi
            echo "</div>"
            [[ $((i % 3)) == 2 ]] && {
                echo "<button type='button' onclick='submitLevel($level)'>Submit Level $level</button>"
                echo "<p class='result' id='result$level'></p></form></div>"
                ((level++))
            }
        done

        echo "<div id='final-result' class='result' style='font-size:1.3em; margin-top: 40px;'></div>"

echo "<script>
let scores = [0, 0, 0, 0];
const correct = {
    q1: 'b', q2: 'a', q3: 'c',
    q4: 'b', q5: 'b', q6: 'b',
    q7: 'c', q8: 'a', q9: 'c',
    q10: 't', q11: 'f', q12: 'f'
};
function submitLevel(level) {
    let start = (level - 1) * 3 + 1;
    let score = 0;
    let feedback = '';
    for (let i = start; i < start + 3; i++) {
        let selected = document.querySelector('input[name=q' + i + ']:checked');
        if (!selected) {
            alert('Please answer question Q' + i);
            return;
        }
        if (selected.value === correct['q' + i]) {
            score++;
            feedback += '✔ Q' + i + ': Correct<br>';
        } else {
            feedback += '❌ Q' + i + ': Incorrect (Correct: ' + correct['q' + i].toUpperCase() + ')<br>';
        }
    }
    scores[level - 1] = score;
    document.getElementById('result' + level).innerHTML = 'Score: ' + score + ' / 3<br>' + feedback;

    document.getElementById('level' + level).classList.add('hidden');
    if (level < 4) {
        document.getElementById('level' + (level + 1)).classList.remove('hidden');
    } else {
        let total = scores.reduce((a, b) => a + b, 0);
        document.getElementById('final-result').innerHTML = '🏁 Total Score: ' + total + ' / 12';
    }
}

window.onload = () => {
    document.getElementById('level1').classList.remove('hidden');
};
</script>"

# New button and answer section
echo "<button onclick=\"document.getElementById('correct-answers').classList.toggle('hidden')\">Show Correct Answers</button>"

echo "<div id='correct-answers' class='hidden' style='margin-top: 30px;'>
<h3>✅ Correct Answers</h3>
<ol>
    <li>Q1: Resource waiting cycle (b)</li>
    <li>Q2: Starvation (a)</li>
    <li>Q3: Priority scheduling (c)</li>
    <li>Q4: To avoid deadlock (b)</li>
    <li>Q5: Need = Max - Allocation (b)</li>
    <li>Q6: Deadlock is impossible (b)</li>
    <li>Q7: Preemption with rollback (c)</li>
    <li>Q8: Increased CPU usage (a)</li>
    <li>Q9: Need matrix (c)</li>
    <li>Q10: True (t)</li>
    <li>Q11: False (f)</li>
    <li>Q12: False (f)</li>
</ol>
</div>"

echo "</body></html>"

        
    } > "$html_file"

    echo -e "\e[32m✔ Exported to $html_file\e[0m"
    command -v xdg-open &> /dev/null && xdg-open "$html_file"
}

menu() {
    while true; do
        echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"

        echo -e "${CYAN}           💡 Deadlock Defender Menu${NC}"

        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${YELLOW}1.${NC} 🧾 View Current System State"
        echo -e "${YELLOW}2.${NC} 🔄 Run Safety Check"
        echo -e "${YELLOW}3.${NC} ➕ Request Resources"
        echo -e "${YELLOW}4.${NC} ➖ Release Resources"
        echo -e "${YELLOW}5.${NC} 📊 Show Process Progress"
        echo -e "${YELLOW}6.${NC} 📈 Show Statistics Report"
        echo -e "${YELLOW}7.${NC} 🌐 Export as HTML Report"
        echo -e "${YELLOW}8.${NC} 🔁 Re-enter New Input (Manual)"
        echo -e "${YELLOW}9.${NC} 🎲 Generate Random Input Scenario"
        echo -e "${YELLOW}10.${NC} 🧠 Learn Deadlock Concepts & Take Quiz"
        echo -e "${YELLOW}11.${NC} ❌ Exit Simulation"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        read -p "Choose an option: " opt
        case $opt in
            1) display_state ;;
            2) check_safe_state ;;
            3) request_resources ;;
            4) release_resources ;;
            5) show_progress_bar ;;
            6) show_stats ;;
            7) export_html_report ;;
            8) read_input ;;

9) generate_random_input; display_state ;;
            10)generate_lessons_and_quiz_html ;;








            11) echo -e "${YELLOW}👋 Exiting Simulation. Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}❌ Invalid option. Please try again.${NC}" ;;
        esac
    done
}
           


# ======= MAIN =======
welcome_splash
      # Clear the log file here before any checks or input

read_input        # Remove generate_random_input here if you want manual input first

display_state
menu
