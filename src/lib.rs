extern crate bytes;
extern crate mio;

mod error;
mod kcp;
pub mod prelude {
    pub use super::{Kcp, get_conv};
}

pub use error::Error;
pub use kcp::{Kcp, get_conv};
