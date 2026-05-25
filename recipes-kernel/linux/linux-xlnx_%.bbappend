# linux-xlnx_%.bbappend — KR260 kernel customisation hook
#
# The Xilinx linux-xlnx kernel recipe is provided by meta-xilinx-core and
# already carries full KR260 / ZynqMP board support.  Add any site-specific
# kernel config fragments or SRC_URI patches here.
#
# Example — add an extra config fragment:
#   FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
#   SRC_URI += "file://zion-extra.cfg"
