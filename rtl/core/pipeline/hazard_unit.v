import cpu_defs::*;

module hazard_unit (
    input wire id_ex_mem_read,
    input wire [REG_ADDR_W-1:0] id_ex_dest,
    input wire [REG_ADDR_W-1:0] if_id_rs,
    input wire [REG_ADDR_W-1:0] if_id_rt,
    input wire ex_busy,
    input wire mem_stall,
    output wire stall_if,
    output wire stall_id,
    output wire flush_id_ex
);
    wire load_use_hazard;
    wire pipeline_blocked;

    assign load_use_hazard = id_ex_mem_read && (id_ex_dest != 0) &&
                             ((id_ex_dest == if_id_rs) || (id_ex_dest == if_id_rt));
    assign pipeline_blocked = ex_busy || mem_stall;

    assign stall_if = load_use_hazard || pipeline_blocked;
    assign stall_id = load_use_hazard || pipeline_blocked;
    assign flush_id_ex = load_use_hazard && !pipeline_blocked;
endmodule

