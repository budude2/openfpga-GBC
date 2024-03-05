rtc_ram	rtc_ram_inst (
	.clock ( clock_sig ),
	.data ( data_sig ),
	.rdaddress ( rdaddress_sig ),
	.wraddress ( wraddress_sig ),
	.wren ( wren_sig ),
	.q ( q_sig )
	);
