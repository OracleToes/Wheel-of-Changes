#!/bin/bash
# THE FRACTAL CALENDAR
# A 6-Layer Base-8 Temporal Descent
#  -c  Clock mode: live matrix of past / present / future hexagrams
#  -w  Watch Mode: live calendar mode
#  supply a personal anchor with --changing, use "YYYY-MM-DD HH:MM:SS" you can omit the hour:minute:second and the script still works

ANCHOR_U="2000-12-21 00:00:00Z"
ANCHOR_P=""
SYMBOL_ONLY=false
CLOCK_MODE=false
WATCH_MODE=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --anchor) ANCHOR_U="$2"; shift 2 ;;
        --changing) ANCHOR_P="$2"; shift 2 ;;
        -s) SYMBOL_ONLY=true; shift ;;
        -c) CLOCK_MODE=true; shift ;;
        -w) WATCH_MODE=true; shift ;;
        *) shift ;;
    esac
done

if [[ -z "$ANCHOR_P" ]]; then
    ANCHOR_P="$ANCHOR_U"
fi

# Convert anchor dates to epoch seconds
SEC_U=$(date -d "$ANCHOR_U" +%s 2>/dev/null)
SEC_P=$(date -d "$ANCHOR_P" +%s 2>/dev/null)

if (( $? != 0 )); then
    echo "Error: Invalid anchor date format."
    exit 1
fi

# Define cycle lengths in quarter‑seconds (original)
PICO_CYCLE_QS=30375                      # 2.109375 hours
NANO_CYCLE_QS=$(( PICO_CYCLE_QS * 8 ))   # 16.875 hours
MICRO_CYCLE_QS=$(( NANO_CYCLE_QS * 8 ))  # 5.625 days
MESO_CYCLE_QS=$(( MICRO_CYCLE_QS * 8 ))  # 45 days
MACRO_CYCLE_QS=$(( MESO_CYCLE_QS * 8 ))  # 360 days
AEON_CYCLE_QS=$(( MACRO_CYCLE_QS * 8 ))  # 2880 days (~7.88 years)

# Step size in seconds for equal‑step approximation (cycle / 8)
#   step_seconds = cycle_qs / (4 * 8)   (4 qs per second)
PICO_STEP=$(awk "BEGIN { printf \"%.10f\", $PICO_CYCLE_QS/32 }")
NANO_STEP=$(awk "BEGIN { printf \"%.10f\", $NANO_CYCLE_QS/32 }")
MICRO_STEP=$(awk "BEGIN { printf \"%.10f\", $MICRO_CYCLE_QS/32 }")
MESO_STEP=$(awk "BEGIN { printf \"%.10f\", $MESO_CYCLE_QS/32 }")
MACRO_STEP=$(awk "BEGIN { printf \"%.10f\", $MACRO_CYCLE_QS/32 }")
AEON_STEP=$(awk "BEGIN { printf \"%.10f\", $AEON_CYCLE_QS/32 }")

# Original functions (for non‑clock mode)
get_fractal_index() {
    local time_in_cycle=$1
    local cycle_length=$2
    local half=$(( cycle_length / 2 ))
    local quarter=$(( cycle_length / 4 ))
    local eighth=$(( cycle_length / 8 ))
    local l1 l2 l3

    if (( time_in_cycle < half )); then l1=0; else l1=1; fi
    if (( time_in_cycle % half < quarter )); then l2=0; else l2=1; fi
    if (( time_in_cycle % quarter < eighth )); then l3=0; else l3=1; fi
    echo $(( l1 * 4 + l2 * 2 + l3 ))
}

get_cycle_pos() {
    local elapsed=$1
    local cycle_len=$2
    local pos=$(( elapsed % cycle_len ))
    if (( pos < 0 )); then pos=$(( pos + cycle_len )); fi
    echo $pos
}

# Data structures
TRIGRAMS=("☰" "☱" "☲" "☳" "☴" "☵" "☶" "☷")
HEX_NAMES=(
    "䷀ 1: Qian (The Creative)" "䷉ 10: Lu (Treading)" "䷌ 13: Tong Ren (Fellowship)" "䷘ 25: Wu Wang (Innocence)" "䷫ 44: Gou (Coming to Meet)" "䷅ 6: Song (Conflict)" "䷠ 33: Dun (Retreat)" "䷋ 12: Pi (Standstill)"
    "䷪ 43: Guai (Breakthrough)" "䷹ 58: Dui (The Joyous)" "䷰ 49: Ge (Revolution)" "䷐ 17: Sui (Following)" "䷛ 28: Da Guo (Preponderance of the Great)" "䷮ 47: Kun (Oppression)" "䷞ 31: Xian (Influence)" "䷬ 45: Cui (Gathering Together)"
    "䷍ 14: Da You (Great Possession)" "䷥ 38: Kui (Opposition)" "䷝ 30: Li (The Clinging)" "䷔ 21: Shi He (Biting Through)" "䷱ 50: Ding (The Caldron)" "䷿ 64: Wei Ji (Before Completion)" "䷷ 56: Lu (The Wanderer)" "䷢ 35: Jin (Progress)"
    "䷡ 34: Da Zhuang (Great Power)" "䷵ 54: Gui Mei (Marrying Maiden)" "䷶ 55: Feng (Abundance)" "䷲ 51: Zhen (The Arousing)" "䷟ 32: Heng (Duration)" "䷧ 40: Xie (Deliverance)" "䷽ 62: Xiao Guo (Preponderance of the Small)" "䷏ 16: Yu (Enthusiasm)"
    "䷈ 9: Xiao Xu (Small Taming)" "䷼ 61: Zhong Fu (Inner Truth)" "䷤ 37: Jia Ren (The Family)" "䷩ 42: Yi (Increase)" "䷸ 57: Xun (The Gentle)" "䷺ 59: Huan (Dispersion)" "䷴ 53: Jian (Development)" "䷓ 20: Guan (Contemplation)"
    "䷄ 5: Xu (Waiting)" "䷻ 60: Jie (Limitation)" "䷾ 63: Ji Ji (After Completion)" "䷂ 3: Chun (Difficulty at Beginning)" "䷯ 48: Jing (The Well)" "䷜ 29: Kan (The Abysmal)" "䷦ 39: Jian (Obstruction)" "䷇ 8: Bi (Holding Together)"
    "䷙ 26: Da Xu (Great Taming)" "䷨ 41: Sun (Decrease)" "䷕ 22: Bi (Grace)" "䷚ 27: Yi (Corners of the Mouth)" "䷑ 18: Gu (Repair)" "䷃ 4: Meng (Youthful Folly)" "䷳ 52: Gen (Keeping Still)" "䷖ 23: Po (Splitting Apart)"
    "䷊ 11: Tai (Peace)" "䷒ 19: Lin (Approach)" "䷣ 36: Ming Yi (Darkening of the Light)" "䷗ 24: Fu (Return)" "䷭ 46: Sheng (Pushing Upward)" "䷆ 7: Shi (The Army)" "䷎ 15: Qian (Modesty)" "䷁ 2: Kun (The Receptive)"
)

# Extract the single‑character hexagram symbols
HEX_SYMBOLS=()
for ((i=0; i<64; i++)); do
    HEX_SYMBOLS[$i]="${HEX_NAMES[$i]:0:1}"
done

# ======================================================
# Reusable clock‑mode helper: computes past, present, future
# hexagram indices for a given step size
# ======================================================
get_layer_hex() {
    local step="$1"
    awk -v t="$NOW" -v a_u="$SEC_U" -v a_p="$SEC_P" -v step="$step" \
    'BEGIN {
        # Universal
        diff_u = t - a_u
        n_u = int(diff_u / step)
        if (diff_u < 0 && diff_u % step != 0) n_u--
        u_cur = n_u % 8
        if (u_cur < 0) u_cur += 8
        t_last_u = a_u + n_u * step

        # Personal
        diff_p = t - a_p
        n_p = int(diff_p / step)
        if (diff_p < 0 && diff_p % step != 0) n_p--
        p_cur = n_p % 8
        if (p_cur < 0) p_cur += 8
        t_last_p = a_p + n_p * step

        t_last = (t_last_u > t_last_p) ? t_last_u : t_last_p

        u_past = (t_last == t_last_u) ? ((u_cur + 7) % 8) : u_cur
        p_past = (t_last == t_last_p) ? ((p_cur + 7) % 8) : p_cur

        n_u_next = n_u + 1; t_next_u = a_u + n_u_next * step
        n_p_next = n_p + 1; t_next_p = a_p + n_p_next * step
        t_next = (t_next_u < t_next_p) ? t_next_u : t_next_p

        u_fut = (t_next == t_next_u) ? ((u_cur + 1) % 8) : u_cur
        p_fut = (t_next == t_next_p) ? ((p_cur + 1) % 8) : p_cur

        printf "%d %d %d", p_past * 8 + u_past, p_cur * 8 + u_cur, p_fut * 8 + u_fut
    }'
}

# ======================================================
# OUTPUT RENDERING & WATCH LOOP
# ======================================================

# Extracted rendering function for timeline
render_dual_timeline() {
    local idx_p=$1
    local idx_u=$2
    local title=$3
    
    # Standard ANSI terminal colors
    local C_GREEN='\033[32m'
    local C_BLUE='\033[34m'
    local C_RED='\033[31m'
    local C_PURPLE='\033[35m'
    local C_RESET='\033[0m'
    
    printf " %-13s " "$title"
    for i in {0..7}; do
        if (( i == idx_p && i == idx_u )); then
            # Aligned: Purple indicators, Green trigram
            printf "${C_PURPLE}》[${C_GREEN}%s${C_PURPLE}]《${C_RESET}" "${TRIGRAMS[$i]}"
        elif (( i == idx_p )); then
            # Personal: Blue indicators, Green trigram
            printf " ${C_BLUE}}(${C_GREEN}%s${C_BLUE}){ ${C_RESET}" "${TRIGRAMS[$i]}"
        elif (( i == idx_u )); then
            # Universal: Red indicators, Green trigram
            printf " ${C_RED}>[${C_GREEN}%s${C_RED}]< ${C_RESET}" "${TRIGRAMS[$i]}"
        else
            # Unhighlighted
            printf "   %s   " "${TRIGRAMS[$i]}"
        fi
    done
    echo ""
}

# Setup terminal controls for Watch Mode
if [ "$WATCH_MODE" = true ]; then
    # Trap cleanup: reset colors, show cursor, and exit
    trap 'printf "\033[0m\033[?25h\n"; exit' INT TERM
    # Hide the blinking cursor
    printf "\033[?25l"
    # Clear the screen ONCE before the loop starts
    printf "\033[2J"
fi

# Terminal colour codes for Clock Mode
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

while true; do
    NOW=$(date +%s)
    CURRENT_SEC=$NOW

    if [ "$WATCH_MODE" = true ]; then
        # Just move the cursor to the top-left (home) instead of clearing
        printf "\033[H"
    fi

    if [ "$CLOCK_MODE" = true ]; then

        # --- Pico layer ---
        read pico_past pico_pres pico_fut <<< $(get_layer_hex "$PICO_STEP")
        PICO_PAST_SYM="${HEX_SYMBOLS[$pico_past]}"
        PICO_PRES_SYM="${HEX_SYMBOLS[$pico_pres]}"
        PICO_FUT_SYM="${HEX_SYMBOLS[$pico_fut]}"

        # --- Nano layer ---
        read nano_past nano_pres nano_fut <<< $(get_layer_hex "$NANO_STEP")
        NANO_PAST_SYM="${HEX_SYMBOLS[$nano_past]}"
        NANO_PRES_SYM="${HEX_SYMBOLS[$nano_pres]}"
        NANO_FUT_SYM="${HEX_SYMBOLS[$nano_fut]}"

        # --- Micro layer ---
        read micro_past micro_pres micro_fut <<< $(get_layer_hex "$MICRO_STEP")
        MICRO_PAST_SYM="${HEX_SYMBOLS[$micro_past]}"
        MICRO_PRES_SYM="${HEX_SYMBOLS[$micro_pres]}"
        MICRO_FUT_SYM="${HEX_SYMBOLS[$micro_fut]}"

        # --- Meso layer ---
        read meso_past meso_pres meso_fut <<< $(get_layer_hex "$MESO_STEP")
        MESO_PAST_SYM="${HEX_SYMBOLS[$meso_past]}"
        MESO_PRES_SYM="${HEX_SYMBOLS[$meso_pres]}"
        MESO_FUT_SYM="${HEX_SYMBOLS[$meso_fut]}"

        # --- Macro layer ---
        read macro_past macro_pres macro_fut <<< $(get_layer_hex "$MACRO_STEP")
        MACRO_PAST_SYM="${HEX_SYMBOLS[$macro_past]}"
        MACRO_PRES_SYM="${HEX_SYMBOLS[$macro_pres]}"
        MACRO_FUT_SYM="${HEX_SYMBOLS[$macro_fut]}"

        # --- Aeon layer ---
        read aeon_past aeon_pres aeon_fut <<< $(get_layer_hex "$AEON_STEP")
        AEON_PAST_SYM="${HEX_SYMBOLS[$aeon_past]}"
        AEON_PRES_SYM="${HEX_SYMBOLS[$aeon_pres]}"
        AEON_FUT_SYM="${HEX_SYMBOLS[$aeon_fut]}"

        # Print matrix
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}\n" \
            "$PICO_PAST_SYM"  "$PICO_PRES_SYM"  "$PICO_FUT_SYM"
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}\n" \
            "$NANO_PAST_SYM"  "$NANO_PRES_SYM"  "$NANO_FUT_SYM"
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}\n" \
            "$MICRO_PAST_SYM" "$MICRO_PRES_SYM" "$MICRO_FUT_SYM"
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}\n" \
            "$MESO_PAST_SYM"  "$MESO_PRES_SYM"  "$MESO_FUT_SYM"
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}" \
            "$MACRO_PAST_SYM" "$MACRO_PRES_SYM" "$MACRO_FUT_SYM"
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}\n" \
            "$MACRO_PAST_SYM" "$MACRO_PRES_SYM" "$MACRO_FUT_SYM"
        printf "${DIM}%s${RESET}%s${DIM}%s${RESET}" \
            "$AEON_PAST_SYM"  "$AEON_PRES_SYM"  "$AEON_FUT_SYM"

    else
        # Calendar Output
        ELAPSED_U_QS=$(( (CURRENT_SEC - SEC_U) * 4 ))
        ELAPSED_P_QS=$(( (CURRENT_SEC - SEC_P) * 4 ))

        AEON_U_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_U_QS $AEON_CYCLE_QS) $AEON_CYCLE_QS)
        MACRO_U_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_U_QS $MACRO_CYCLE_QS) $MACRO_CYCLE_QS)
        MESO_U_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_U_QS $MESO_CYCLE_QS) $MESO_CYCLE_QS)
        MICRO_U_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_U_QS $MICRO_CYCLE_QS) $MICRO_CYCLE_QS)
        NANO_U_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_U_QS $NANO_CYCLE_QS) $NANO_CYCLE_QS)
        PICO_U_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_U_QS $PICO_CYCLE_QS) $PICO_CYCLE_QS)

        AEON_P_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_P_QS $AEON_CYCLE_QS) $AEON_CYCLE_QS)
        MACRO_P_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_P_QS $MACRO_CYCLE_QS) $MACRO_CYCLE_QS)
        MESO_P_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_P_QS $MESO_CYCLE_QS) $MESO_CYCLE_QS)
        MICRO_P_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_P_QS $MICRO_CYCLE_QS) $MICRO_CYCLE_QS)
        NANO_P_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_P_QS $NANO_CYCLE_QS) $NANO_CYCLE_QS)
        PICO_P_IDX=$(get_fractal_index $(get_cycle_pos $ELAPSED_P_QS $PICO_CYCLE_QS) $PICO_CYCLE_QS)

        if [ "$SYMBOL_ONLY" = true ]; then
            H1_FULL="${HEX_NAMES[$(( PICO_P_IDX * 8 + PICO_U_IDX ))]}"
            H2_FULL="${HEX_NAMES[$(( NANO_P_IDX * 8 + NANO_U_IDX ))]}"
            H3_FULL="${HEX_NAMES[$(( MICRO_P_IDX * 8 + MICRO_U_IDX ))]}"
            H4_FULL="${HEX_NAMES[$(( MESO_P_IDX * 8 + MESO_U_IDX ))]}"
            H5_FULL="${HEX_NAMES[$(( MACRO_P_IDX * 8 + MACRO_U_IDX ))]}"
            H6_FULL="${HEX_NAMES[$(( AEON_P_IDX * 8 + AEON_U_IDX ))]}"
            
            printf "%s" "${H1_FULL:0:1}${H2_FULL:0:1}${H3_FULL:0:1}${H4_FULL:0:1}${H5_FULL:0:1}"
        else
            echo "==============================================================================="
            printf "    LEGEND:  \033[31m>[\033[32m \033[31m]<\033[0m Universal/Fate   \033[34m}(\033[32m \033[34m){\033[0m Personal/Will   \033[35m》[\033[32m \033[35m]《\033[0m Alignment    \n"
            echo "==============================================================================="
            render_dual_timeline $AEON_P_IDX $AEON_U_IDX "AEON  (7.88y)"
            render_dual_timeline $MACRO_P_IDX $MACRO_U_IDX "MACRO (360d)"
            render_dual_timeline $MESO_P_IDX $MESO_U_IDX "MESO  (45d)"
            render_dual_timeline $MICRO_P_IDX $MICRO_U_IDX "MICRO (5.6d)"
            render_dual_timeline $NANO_P_IDX $NANO_U_IDX "NANO  (16.8h)"
            render_dual_timeline $PICO_P_IDX $PICO_U_IDX "PICO  (2.1h)"
            printf -- "---\033[K\n"
            printf " THE SPINE OF NOW (The Emergent Hexagrams): \033[K\n"
            printf "  L5 (Shi)    : %s\033[K\n" "${HEX_NAMES[$(( PICO_P_IDX * 8 + PICO_U_IDX ))]}"
            printf "  L4 (Watch)  : %s\033[K\n" "${HEX_NAMES[$(( NANO_P_IDX * 8 + NANO_U_IDX ))]}"
            printf "  L3 (Pulse)  : %s\033[K\n" "${HEX_NAMES[$(( MICRO_P_IDX * 8 + MICRO_U_IDX ))]}"
            printf "  L2 (Phase)  : %s\033[K\n" "${HEX_NAMES[$(( MESO_P_IDX * 8 + MESO_U_IDX ))]}"
            printf "  L1 (Year)   : %s\033[K\n" "${HEX_NAMES[$(( MACRO_P_IDX * 8 + MACRO_U_IDX ))]}"
            printf "  L1 (Epoch)  : %s\033[K\n" "${HEX_NAMES[$(( AEON_P_IDX * 8 + AEON_U_IDX ))]}"
            printf "===============================================================================\033[K"
        fi
    fi

    # Loop if watching, otherwise exit
    if [ "$WATCH_MODE" = true ]; then
        # Clear any leftover trailing lines and wait
        printf "\033[0J"
        sleep 10
    else
        # Print a final newline so your terminal prompt looks normal, then exit
        printf "\n"
        break
    fi
done
