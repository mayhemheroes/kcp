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
        let mut fuzz_data = &data[5..];
        let mut mut_fuzz_data = vec![0 as u8; data.len() - 5];
        mut_fuzz_data.clone_from_slice(fuzz_data);
        let mut mut_slice_fuzz_data = &mut mut_fuzz_data[..];
        match opt {
            0=> {
                let mut kcp= Kcp::new(conv, KcpOutput {} );
                let a = kcp.input(fuzz_data);
                kcp.update(conv);
                kcp.flush();
            },
            1=> {
                let mut kcp= Kcp::new_stream(conv, KcpOutput {} );
                let a = kcp.input(fuzz_data);
                kcp.update(conv);
                kcp.flush();
            },
            2=> {
                let mut kcp= Kcp::new(conv, KcpOutput {} );
                let a = kcp.input(fuzz_data);
                kcp.move_buf();
                let b = kcp.recv(&mut mut_slice_fuzz_data);
                kcp.update(conv);
                kcp.flush();
            },
            3=> {
                let mut kcp= Kcp::new_stream(conv, KcpOutput {} );
                let a = kcp.input(fuzz_data);
                kcp.move_buf();
                let b = kcp.recv(&mut mut_slice_fuzz_data);
                kcp.update(conv);
                kcp.flush();
            },
            4=> {
                let mut kcp= Kcp::new(conv, KcpOutput {} );
                let a = kcp.send(fuzz_data);
                kcp.update(conv);
                kcp.flush();
            },
            5=> {
                let mut kcp= Kcp::new_stream(conv, KcpOutput {} );
                let a = kcp.send(fuzz_data);
                kcp.update(conv);
                kcp.flush();
            },
            _=> ()
        }
    }
});
