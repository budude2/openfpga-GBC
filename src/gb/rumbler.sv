module rumbler (
	input logic clk,
	input logic reset,

	input logic rumble_en,
	input logic rumbling,

	output logic cart_wr,
	output logic cart_rumble
);

assign cart_rumble = currRumble;

typedef enum {
    IDLE,
    FLIPBIT,
    DELAY_1,
    WRITE,
    DELAY_2
} stateType;

stateType currState, nextState;
reg [31:0] currCount, nextCount;
reg currRumble, nextRumble;

always_ff @(posedge clk) begin
    if(reset) begin
        currState <= IDLE;
        currCount <= 0;
        currRumble <= 0;
    end else begin
        currState <= nextState;
        currCount <= nextCount;
        currRumble <= nextRumble;
    end
end

always_comb begin
    nextState = currState;
    nextCount = currCount;
    nextRumble = currRumble;
    cart_wr = 1'b1;

    case(currState)

        IDLE: begin
            if(rumble_en & rumbling) begin
            	nextState = FLIPBIT;
            end
        end

        FLIPBIT: begin
            nextRumble = ~currRumble;
            nextState = DELAY_1;
        end

        DELAY_1: begin
        	nextCount = currCount + 1;

        	if(currCount > 7) begin
        		nextState = WRITE;
        		nextCount = 0;
        	end
        end

        WRITE: begin
            cart_wr = 0;
            nextCount = currCount + 1;

            if(currCount > 7) begin
        		nextState = DELAY_2;
        		nextCount = 0;
        	end
        end

        DELAY_2: begin
        	nextCount = currCount + 1;

        	if (currCount > 85190) begin
        		if(rumble_en & rumbling) begin
        			nextState = FLIPBIT;
        		end else begin
        			nextState = IDLE;
        		end
        	end
        end

    endcase
end


endmodule : rumbler