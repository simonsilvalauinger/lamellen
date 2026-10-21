//! Gemeinsame Typen und Logik für Lamellen-Knoten und Gateway.
//!
//! Alles hier ist `no_std` und hardwarefrei, damit es auf dem Host getestet
//! werden kann (`cargo test`).

#![no_std]

pub mod logic;
pub mod message;
pub mod room;
pub mod servo;

pub use message::{Command, DecodeError, Message, Status, StatusFlags, decode, encode};
pub use room::Room;
