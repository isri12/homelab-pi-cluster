#!/bin/bash
#
# Raspberry Pi cgroup Diagnostic Script
# This script checks all possible sources of cgroup configuration issues
#

OUTPUT_FILE="cgroup_report.txt"
HOSTNAME=$(hostname)

echo "======================================================================"
echo "Raspberry Pi cgroup Diagnostic Report"
echo "======================================================================"
echo "Hostname: $HOSTNAME"
echo "Date: $(date)"
echo "======================================================================"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo "----------------------------------------------------------------------"
    echo "$1"
    echo "----------------------------------------------------------------------"
}

# Function to check if file exists and print content
check_file() {
    local file=$1
    local description=$2
    
    print_section "$description"
    if [ -f "$file" ]; then
        echo "File exists: $file"
        echo ""
        echo "Content:"
        cat "$file"
        echo ""
        
        # Check for cgroup-related content
        if grep -qi "cgroup" "$file" 2>/dev/null; then
            echo ">>> cgroup-related lines found:"
            grep -i "cgroup" "$file" | sed 's/^/    /'
        else
            echo ">>> No cgroup-related configuration found"
        fi
    else
        echo "File does not exist: $file"
    fi
}

# Redirect all output to both terminal and file
{
    print_section "1. CURRENT RUNTIME STATUS"
    echo "Current kernel command line (/proc/cmdline):"
    cat /proc/cmdline
    echo ""
    
    echo ">>> Checking for cgroup_disable:"
    if grep -q "cgroup_disable" /proc/cmdline; then
        echo "    ⚠️  WARNING: cgroup_disable found in kernel cmdline!"
        grep -o "cgroup_disable=[^ ]*" /proc/cmdline | sed 's/^/    /'
    else
        echo "    ✓ No cgroup_disable found"
    fi
    echo ""
    
    echo ">>> Checking for cgroup_enable:"
    if grep -q "cgroup_enable" /proc/cmdline; then
        echo "    ✓ cgroup_enable found in kernel cmdline"
        grep -o "cgroup_enable=[^ ]*" /proc/cmdline | sed 's/^/    /'
    else
        echo "    ⚠️  WARNING: No cgroup_enable found"
    fi
    echo ""
    
    echo "Current cgroup status (/proc/cgroups):"
    cat /proc/cgroups
    echo ""
    
    echo ">>> Memory cgroup status:"
    if grep -q "^memory" /proc/cgroups; then
        echo "    ✓ Memory cgroup is present"
        grep "^memory" /proc/cgroups | sed 's/^/    /'
        
        # Check if enabled (last column should be 1)
        ENABLED=$(grep "^memory" /proc/cgroups | awk '{print $4}')
        if [ "$ENABLED" = "1" ]; then
            echo "    ✓ Memory cgroup is ENABLED"
        else
            echo "    ✗ Memory cgroup is DISABLED"
        fi
    else
        echo "    ✗ Memory cgroup is NOT present (this is the problem!)"
    fi

    print_section "2. BOOT CONFIGURATION FILES"
    
    # Check /boot/firmware/ directory
    echo "Boot directory listing:"
    ls -lah /boot/firmware/*.txt 2>/dev/null || echo "No .txt files in /boot/firmware/"
    echo ""
    
    # Check all possible config files
    check_file "/boot/firmware/config.txt" "Main Boot Config (config.txt)"
    check_file "/boot/firmware/cmdline.txt" "Kernel Command Line (cmdline.txt)"
    check_file "/boot/firmware/usercfg.txt" "User Config (usercfg.txt)"
    check_file "/boot/firmware/syscfg.txt" "System Config (syscfg.txt)"
    check_file "/boot/firmware/extraargs.txt" "Extra Arguments (extraargs.txt)"
    check_file "/boot/firmware/autoboot.txt" "Autoboot Config (autoboot.txt)"
    
    # Check alternative /boot/ location
    check_file "/boot/config.txt" "Alternative Boot Config (/boot/config.txt)"
    check_file "/boot/cmdline.txt" "Alternative Kernel Command Line (/boot/cmdline.txt)"

    print_section "3. FIRMWARE INFORMATION"
    echo "Firmware version:"
    vcgencmd version 2>/dev/null || echo "vcgencmd not available"
    echo ""
    
    echo "Bootloader version:"
    if [ -f /boot/firmware/pieeprom.upd ]; then
        rpi-eeprom-config /boot/firmware/pieeprom.upd 2>/dev/null || echo "Cannot read EEPROM config"
    else
        vcgencmd bootloader_version 2>/dev/null || echo "Bootloader version not available"
    fi

    print_section "4. SYSTEM INFORMATION"
    echo "OS Information:"
    cat /etc/os-release | grep -E "PRETTY_NAME|VERSION" || echo "OS info not available"
    echo ""
    
    echo "Kernel version:"
    uname -a
    echo ""
    
    echo "Raspberry Pi model:"
    cat /proc/device-tree/model 2>/dev/null || echo "Model info not available"
    echo ""
    
    echo "Memory info:"
    free -h

    print_section "5. GRUB/BOOT CONFIGURATION (if applicable)"
    if [ -f /boot/grub/grub.cfg ]; then
        echo "GRUB config found (checking for cgroup settings):"
        grep -i cgroup /boot/grub/grub.cfg | sed 's/^/    /' || echo "No cgroup settings in GRUB"
    else
        echo "No GRUB configuration (normal for Raspberry Pi)"
    fi
    
    if [ -f /etc/default/grub ]; then
        echo ""
        echo "GRUB defaults (checking for cgroup settings):"
        grep -i cgroup /etc/default/grub | sed 's/^/    /' || echo "No cgroup settings in GRUB defaults"
    fi

    print_section "6. SYSTEMD CONFIGURATION"
    echo "Checking systemd cgroup configuration:"
    if [ -f /etc/systemd/system.conf ]; then
        echo "systemd system.conf cgroup settings:"
        grep -i cgroup /etc/systemd/system.conf | sed 's/^/    /' || echo "No cgroup settings"
    fi
    echo ""
    
    echo "Current systemd cgroup hierarchy:"
    if [ -d /sys/fs/cgroup/unified ]; then
        echo "    Using unified cgroup hierarchy (cgroup v2)"
    elif [ -d /sys/fs/cgroup/memory ]; then
        echo "    Using legacy cgroup hierarchy (cgroup v1)"
    else
        echo "    ⚠️  Cgroup filesystem not properly mounted"
    fi

    print_section "7. PACKAGE VERSIONS"
    echo "Kernel package:"
    dpkg -l | grep -E "linux-image|raspberrypi-kernel" | awk '{print $2, $3}' || echo "Not available"
    echo ""
    
    echo "Firmware package:"
    dpkg -l | grep -E "raspberrypi-bootloader|firmware" | awk '{print $2, $3}' || echo "Not available"

    print_section "8. DIAGNOSTIC SUMMARY"
    
    echo "Issue Analysis:"
    echo "==============="
    
    # Check for the main issue
    if ! grep -q "^memory" /proc/cgroups; then
        echo "❌ PROBLEM FOUND: Memory cgroup is NOT available"
        echo ""
        
        # Check what's causing it
        if grep -q "cgroup_disable=memory" /proc/cmdline; then
            echo "🔍 ROOT CAUSE: Kernel has 'cgroup_disable=memory' parameter"
            echo ""
            echo "Recommended fixes:"
            echo "1. Check /boot/firmware/config.txt for cgroup_disable"
            echo "2. Ensure /boot/firmware/cmdline.txt has cgroup_enable=memory"
            echo "3. Add to /boot/firmware/config.txt:"
            echo "   [all]"
            echo "   cgroup_enable=memory"
            echo "   cgroup_memory=1"
            echo ""
            echo "4. Or create /boot/firmware/extraargs.txt with:"
            echo "   cgroup_enable=memory cgroup_memory=1"
        elif ! grep -q "cgroup_enable=memory" /proc/cmdline; then
            echo "🔍 ROOT CAUSE: Kernel is missing 'cgroup_enable=memory' parameter"
            echo ""
            echo "Recommended fixes:"
            echo "1. Add to /boot/firmware/cmdline.txt:"
            echo "   cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"
            echo ""
            echo "2. AND add to /boot/firmware/config.txt:"
            echo "   [all]"
            echo "   cgroup_enable=memory"
            echo "   cgroup_memory=1"
        else
            echo "🔍 UNCLEAR: cgroup parameters are set but memory cgroup still not available"
            echo "   This might be a firmware or kernel bug"
            echo ""
            echo "Try:"
            echo "1. Update firmware: sudo apt update && sudo apt full-upgrade"
            echo "2. Update bootloader: sudo rpi-eeprom-update -a"
            echo "3. Reboot and check again"
        fi
    else
        ENABLED=$(grep "^memory" /proc/cgroups | awk '{print $4}')
        if [ "$ENABLED" = "1" ]; then
            echo "✅ SUCCESS: Memory cgroup is available and ENABLED"
            echo "   No action needed - system is configured correctly"
        else
            echo "⚠️  WARNING: Memory cgroup exists but is DISABLED"
            echo "   This is unusual - check systemd configuration"
        fi
    fi

    print_section "9. FILES TO CHECK MANUALLY"
    echo "If the issue persists, manually inspect these files:"
    echo ""
    echo "Critical files:"
    echo "  - /boot/firmware/config.txt"
    echo "  - /boot/firmware/cmdline.txt"
    echo ""
    echo "Additional files to check:"
    for file in /boot/firmware/*.txt /boot/*.txt; do
        if [ -f "$file" ]; then
            echo "  - $file"
        fi
    done

    echo ""
    echo "======================================================================"
    echo "End of diagnostic report"
    echo "======================================================================"
    echo ""
    echo "Report saved to: $OUTPUT_FILE"
    echo "Upload this file for further assistance"

} 2>&1 | tee "$OUTPUT_FILE"

echo ""
echo "✓ Diagnostic complete!"
echo "Review the report above or check: $OUTPUT_FILE"
