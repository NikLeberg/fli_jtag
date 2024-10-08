-- =============================================================================
-- File:                    fli_jtag.vhdl
--
-- Entity:                  fli_jtag
--
-- Description:             Simulation only virtual JTAG "connector". Allows to
--                          connect to the running ModelSim / QuestaSim through
--                          OpenOCD.
--
-- Note:                    Logic that is driven by this JTAG "connector" is
--                          usually assuming some relation between clk and tck
--                          i.e. is doing some clock crossing. Use the DELAY
--                          generic to enforce this relation. Only set DELAY = 0
--                          if the driven logic is capable of processing
--                          changing tck, tms, and tdi signals on each clk.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2024-09-15, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fli_jtag IS
    GENERIC (
        DELAY : NATURAL := 3 -- delay in counts of clk, 0 is no delay
    );
    PORT (
        clk : IN STD_ULOGIC; -- system clock
        tdo : IN STD_ULOGIC;
        tck, tms, tdi : OUT STD_LOGIC;
        trst : OUT STD_LOGIC; -- JTAG TAP reset, active-high
        srst : OUT STD_LOGIC -- system reset, active-high
    );
END ENTITY;

ARCHITECTURE sim OF fli_jtag IS

    -- Exchange values between VHDL and C through MTI FLI.
    PROCEDURE tick (
        tdo : IN STD_ULOGIC; -- current value of tdo
        tck, tms, tdi, trst, srst : OUT STD_ULOGIC
    ) IS
    BEGIN
        -- dummy implementation, gets overwritten by C function fli_jtag_tick
        REPORT "ERROR: foreign subprogram fli_jtag_tick not called" SEVERITY failure;
    END;
    ATTRIBUTE foreign OF tick : PROCEDURE IS "fli_jtag_tick fli_jtag.so";

    SIGNAL delay_count, delay_count_next : NATURAL RANGE 0 TO DELAY := 0;

BEGIN

    delay_count_next <= 0 WHEN delay_count >= DELAY ELSE
        delay_count + 1;
    delay_count <= delay_count_next WHEN rising_edge(clk);

    jtag_tick : PROCESS (clk)
        VARIABLE v_tck, v_tms, v_tdi, v_trst, v_srst : STD_ULOGIC;
    BEGIN
        IF rising_edge(clk) THEN
            IF delay_count = 0 THEN
                tick(tdo, v_tck, v_tms, v_tdi, v_trst, v_srst);
                tck <= v_tck;
                tms <= v_tms;
                tdi <= v_tdi;
                trst <= v_trst;
                srst <= v_srst;
            END IF;
        END IF;
    END PROCESS jtag_tick;

END ARCHITECTURE;