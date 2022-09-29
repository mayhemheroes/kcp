#![no_main]
use libfuzzer_sys::fuzz_target;
use std::io::{self, Write};
use kcp::Kcp;

fuzz_target!(|data: &[u8]| {
    struct KcpOutput {
    }
    
    impl Write for KcpOutput {
        fn write(&mut self, data: &[u8]) -> io::Result<usize> {
            Ok(data.len())
        }
    
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    if data.len() > 5 {
        let opt = data[0];
        let conv = unsafe{std::ptr::read(&data[1])} as u32;
        let fuzz_data = &data[5..];
        match opt {
            0=> {
                let mut kcp= Kcp::new(conv, KcpOutput {} );
                let _ = kcp.input(fuzz_data);
            },
            1=> {
                let mut kcp= Kcp::new_stream(conv, KcpOutput {} );
                let _ = kcp.input(fuzz_data);
            },
            2=> {
                let mut kcp= Kcp::new(conv, KcpOutput {} );
                let _ = kcp.send(fuzz_data);
            },
            3=> {
                let mut kcp= Kcp::new_stream(conv, KcpOutput {} );
                let _ = kcp.send(fuzz_data);
            },
            _=> ()
        }
    }
});
