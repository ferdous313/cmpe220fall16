# makes a wrapper module for a .v file by breaking
# the structs and using the types for each component of the struct to make a
# serialized interface


# TO USE: change the module name and instance name in script
# $ python2 make_wp.py filename.v > filename_wp.v
# if the struct you need is not here, add to dict


import sys

modulename = 'top_2core2dr'
instancename = 'top'

dict = {'I_drtol2_snack_type': [
            ('SC_nodeid_type\t', 'nid'),
            ('L2_reqid_type\t', 'l2id'),
            ('DR_reqid_type\t', 'drid'),
            ('SC_snack_type\t', 'snack'),
            ('SC_line_type\t', 'line'),
            ('SC_paddr_type\t', 'paddr')],
	'I_l1tol2tlb_req_type': [
	    ('L1_reqid_type\t', '1lid'),
	    ('logic\t', 'prefetch'),
	    ('SC_poffset_type\t', 'poffset'),
	    ('TLB_hpaddr_type\t', 'hpaddr')],
	'I_l2tlbtol2_fwd_type': [
	    ('L1_reqid_type\t', '1lid'),
	    ('logic\t', 'prefetch'),
	    ('SC_fault_type\t', 'fault'),
	    ('TLB_hpaddr_type\t', 'hpaddr'),
	    ('SC_paddr_type\t', 'paddr')],
	'I_l2tlbtol1tlb_snoop_type': [
	    ('TLB_reqid_type\t', 'rid'),
	    ('TLB_hpaddr_type\t', 'hpaddr')],
	'I_l2tlbtol1tlb_ack_type': [
	    ('TLB_reqid_type\t', 'rid'),
	    ('TLB_hpaddr_type\t', 'hpaddr'),
	    ('SC_ppaddr_type\t', 'ppaddr'),
	    ('SC_dctlbe_type\t', 'dctlbe')],
	'I_l1tlbtol2tlb_req_type': [
	    ('TLB_reqid_type\t', 'rid'),
	    ('logic\t\t\t', 'disp_req'),
	    ('logic\t\t\t', 'disp_A'),
	    ('logic\t\t\t', 'disp_D'),
	    ('TLB_hpaddr_type\t', 'disp_hpaddr'),
	    ('SC_laddr_type\t', 'laddr'),
	    ('SC_sptbr_type\t', 'sptbr')],
	'I_l1tlbtol2tlb_sack_type': [
	    ('TLB_reqid_type\t', 'rid')],
        'I_l2todr_disp_type':[
            ('SC_nodeid_type\t', 'nid'),
            ('L2_reqid_type\t','l2id'),
            ('DR_reqid_type\t', 'drid'),
            ('SC_disp_mask_type', 'mask'),
            ('SC_dcmd_type\t', 'dcmd'),
            ('SC_line_type\t', 'line'),
            ('SC_paddr_type\t', 'paddr')],
        'I_drtol2_dack_type':[
            ('SC_nodeid_type\t', 'nid'),
            ('L2_reqid_type\t', 'l2id')],
        'I_l2snoop_ack_type':[
            ('L2_reqid_type\t', 'l2id'),
	    ('DR_ndirs_type\t', 'directory_id')],
	'I_l2todr_pfreq_type':[
	    ('SC_nodeid_type\t', 'nid'),
            ('SC_paddr_type\t', 'paddr')],
        'I_drsnoop_ack_type':[
            ('DR_reqid_type\t', 'drid')],
        'I_l2todr_req_type':[
            ('SC_nodeid_type\t', 'nid'),
            ('L2_reqid_type\t','l2id'),
            ('SC_cmd_type\t\t', 'cmd'),
            ('SC_paddr_type\t', 'paddr')],
        'I_drtomem_wb_type':[
            ('SC_line_type\t', 'line'),
            ('SC_paddr_type\t', 'paddr')],
        'I_drtomem_req_type':[
            ('DR_reqid_type\t', 'drid'),
            ('SC_cmd_type\t\t', 'cmd'),
            ('SC_paddr_type\t', 'paddr')],
        'I_drtomem_pfreq_type':[
            ('SC_nodeid_type\t', 'nid'),
            ('SC_paddr_type\t', 'paddr')],
        'I_coretodc_ld_type':[
            ('DC_ckpid_type\t', 'ckpid'),
            ('CORE_reqid_type\t', 'coreid'),
            ('CORE_lop_type\t', 'lop'),
            ('logic\t\t\t', 'pnr'),
            ('SC_pcsign_type\t', 'pcsign'),
            ('SC_poffset_type\t', 'poffset'),
            ('SC_imm_type\t\t', 'imm')],
        'I_pfgtopfe_op_type':[
            ('PF_delta_type\t', 'delta'),
            ('PF_weigth_type\t', 'w1'),
            ('PF_weigth_type\t', 'w2'),
            ('SC_pcsign_type\t', 'pcsign'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_sptbr_type\t', 'sptbr')],
        'I_memtodr_ack_type':[
            ('DR_reqid_type\t', 'drid'),
            ('SC_nodeid_type\t', 'nid'),
            ('SC_paddr_type\t', 'paddr'),
            ('SC_snack_type\t', 'ack'),
            ('SC_line_type\t', 'line')],
        'I_dctocore_std_ack_type':[
            ('SC_fault_type\t', 'fault'),
            ('CORE_reqid_type\t', 'coreid')],
        'I_ictocore_type':[
            ('CORE_reqid_type\t', 'coreid'),
            ('SC_fault_type\t', 'fault'),
            ('IC_fwidth_type\t', 'data')],
        'I_coretodc_std_type':[
            ('DC_ckpid_type\t', 'ckpid'),
            ('CORE_reqid_type\t', 'coreid'),
            ('CORE_mop_type\t', 'mop'),
            ('logic\t\t\t', 'pnr'),
            ('SC_pcsign_type\t', 'pcsign'),
            ('SC_poffset_type\t', 'poffset'),
            ('SC_imm_type\t\t', 'imm'),
            ('SC_line_type\t', 'data')],
        'I_dctocore_ld_type':[
            ('CORE_reqid_type\t', 'coreid'),
            ('SC_fault_type\t', 'fault'),
            ('SC_line_type\t', 'data')],
        'I_coretodctlb_ld_type':[
            ('DC_ckpid_type\t', 'ckpid'),
            ('CORE_reqid_type\t', 'coreid'),
            ('CORE_lop_type\t', 'lop'),
            ('logic\t\t\t', 'pnr'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_imm_type\t\t', 'imm'),
            ('SC_sptbr_type\t', 'sptbr'),
            ('logic\t\t\t', 'user')],
        'I_coretodctlb_st_type':[
            ('DC_ckpid_type\t', 'ckpid'),
            ('CORE_reqid_type\t', 'coreid'),
            ('CORE_mop_type\t', 'mop'),
            ('logic\t\t\t', 'pnr'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_imm_type\t\t', 'imm'),
            ('SC_sptbr_type\t', 'sptbr'),
            ('logic\t\t\t', 'user')],
        'I_pfetol1tlb_req_type':[
            ('logic\t\t\t', 'l2'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_sptbr_type\t', 'sptbr')],
        'I_l1tlbtol1_fwd_type':[
            ('CORE_reqid_type\t', 'coreid'),
            ('logic\t\t\t', 'prefetch'),
            ('logic\t\t\t', 'l2_prefetch'),
            ('SC_fault_type\t', 'fault'),
            ('TLB_hpaddr_type\t', 'hpaddr'),
            ('SC_ppaddr_type\t', 'ppaddr')],
        'I_l1tlbtol1_cmd_type':[
            ('logic\t\t\t', 'flush'),
            ('TLB_hpaddr_type\t', 'hpaddr')],
        'I_coretoictlb_pc_type':[
            ('CORE_reqid_type\t', 'coreid'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_sptbr_type\t', 'sptbr')],
        'I_coretoic_pc_type':[
            ('CORE_reqid_type\t', 'coreid'),
            ('SC_poffset_type\t', 'poffset')],
        'I_coretodctlb_ld_type':[
            ('DC_ckpid_type\t', 'ckpid'),
            ('CORE_reqid_type\t', 'coreid'),
            ('CORE_lop_type\t', 'lop'),
            ('logic\t\t\t', 'pnr'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_imm_type\t\t', 'imm'),
            ('SC_sptbr_type\t', 'sptbr'),
            ('logic\t\t\t', 'user')],
        'I_coretodctlb_st_type':[
            ('DC_ckpid_type\t', 'ckpid'),
            ('CORE_reqid_type\t', 'coreid'),
            ('CORE_mop_type\t', 'mop'),
            ('logic\t\t\t', 'pnr'),
            ('SC_laddr_type\t', 'laddr'),
            ('SC_imm_type\t', 'imm'),
            ('SC_sptbr_type\t', 'sptbr'),
            ('logic\t\t\t', 'user')],
        }

content = []
new_content = ['\n\n']

with open(sys.argv[1]) as f:
    content = f.readlines()


print '/* this file automatically generated by make_wp.py script'
print ' * for file ' + sys.argv[1]
print ' * for module ' + modulename
print ' * with the instance name ' + instancename
print ' */'
print ''

for line in content:
    words = line.split()
    if len(words) > 0 and (words[0] == ',input' or words[0] == ',output' or words[0] == 'input' or words[0] == 'output'):
        if words[1] in dict.keys():
            types = dict.get(words[1])
            print "\t//" + line,
            new_content.append('\n\t' + words[1] + ' ' + words[2] + ';')
            for type in types:
                print '\t' + words[0] + '\t'+ type[0] +'\t' + words[2] + '_' + type[1]
                #this should generate the assign statements that are needed for breaking the structs
                #not tested at all. Comment if statement below if it does not work for you.
                if words[0] == ',input' or words[0] == 'input': #its an input
                    new_content.append('\tassign ' + words[2] + '.' + type[1] + ' = ' + words[2] + '_' + type[1] + ';')
                else: #its an output
                    new_content.append('\tassign ' + words[2] + '_' + type[1] + ' = ' + words[2] + '.' + type[1] + ';')
        elif words[1] == 'logic':
            print '\t' + words[0] + '\tlogic\t\t\t\t' +  words[2]
        elif len(words) > 1 and words[1].startswith('I_'):
            print '//POSSIBLE PROBLEM: ' + words[1] + ' MAY BE A STRUCT TYPE make_wp.py DOES NOT RECOGNIZE'
            print '//PLEASE ADD STRUCT TYPE ' + words[1] + ' TO dict{} AND RERUN'
            print line,
        elif len(words) ==3 and words[1][0].isupper:
            print '\t' + words[0] + '\t' + words[1] + '\t\t' + words[2]
        elif len(words) == 2 and words[1][0].islower:
            print '\t' + words[0] + '\tlogic\t\t\t\t' +  words[1]
        else:
            print '\t' + words[0] + '\tlogic\t\t\t\t' +  words[1]
    elif len(words) > 0 and words[0] == 'module':
        print 'module ' + modulename + '_wp('
    elif len(words) > 0 and (words[0] == '`ifdef' or words[0] == '`endif'):
        new_content.append('\n')
        new_content.append(line)
        print line,
    elif len(words) > 0 and words[0] == 'endmodule':
        #this should print out all the "assigns" that are needed from breaking the structs
        for new_line in new_content:
            print new_line
        #this should print out the module and instance names set above
        print '\n\n' + modulename + ' ' + instancename +  '(.*);'
        print line,
    elif line == ');\n':
        print line,
        #this should print out all the "assigns" that are needed from breaking the structs
        for new_line in new_content:
            print new_line
        #this should print out the module and instance names set above
        print '\n\n' + modulename + ' ' + instancename +  '(.*);'
        print 'endmodule'
        break
    else:
        print line,
