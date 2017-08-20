program chip8emu;

uses sysutils, crt {$IFDEF WIN32},Windows{$ENDIF};

const
      key1 = 49;
      key2 = 50;
      key3 = 51;
      key4 = 52;
      key_a = 97;
      key_b = 98;
      key_c = 99;
      key_d = 100;
      key_e = 101;
      key_f = 102;
      key_g = 103;
      key_h = 104;
      key_i = 105;
      key_j = 106;
      key_k = 107;
      key_l = 108;
      key_m = 109;
      key_n = 110;
      key_o = 111;
      key_p = 112;
      key_q = 113;
      key_r = 114;
      key_s = 115;
      key_t = 116;
      key_u = 117;
      key_v = 118;
      key_w = 119;
      key_x = 120;
      key_y = 121;
      key_z = 122;
      memory_size = $1000;
      graphic_size = $800;
      graphic_width = 64;
      graphic_height = 32;
      instruction_byte = 2;
      char_bottom = 220;
      char_space = 32;
      char_top = 223;
      char_whole = 219;
      font_address = $50;
      key_esc = 27;
      start_address = $200;
      stack_size = $10;
      sprite_width = 8;
      register_size = $10;
      keys_size = $10;

type graphic_arr = array[0..graphic_size] of byte;
     memory_arr = array[0..memory_size] of byte;
     stack_arr = array[0..stack_size] of integer;
     register_arr = array[0..register_size] of byte;
     key_arr = array[0..keys_size] of boolean;

var delay_timer, frequency: integer;
    index_register, stack_pointer: integer;
    running, should_draw, exitop: boolean;
    instruction: longint;
    program_counter, sound_timer: integer;
    graphics: graphic_arr;
    memory: memory_arr;
    stack: stack_arr;
    keys: key_arr;
    registers: register_arr;
    rom_path: string;

{$IFDEF WIN32}
procedure putch(const a: integer);
var lunused: longword;
    c: char;
begin
       c := chr(a);
       WriteConsole(GetStdHandle(STD_OUTPUT_HANDLE), @c, 1, lunused, nil);
end;
{$ELSE}
procedure putch(const a: integer);
begin
        write(Chr(a));
end;
{$ENDIF}


function get_key: integer;
var t: char;
begin
        t:= ReadKey;

        case (ord(t)) of
                key1: exit($1);
                key2: exit($2);
                key3: exit($3);
                key_q: exit($4);
                key_w: exit($5);
                key_e: exit($6);
                key_a: exit($7);
                key_s: exit($8);
                key_d: exit($9);
                key4: exit($c);
                key_f: exit($e);
                key_z: exit($a);
                key_x: exit(0);
                key_c: exit($b);
                key_v: exit($f);
                key_esc: running := false;
                else exit(-1);
        end;

end;

function operand_n: integer;
begin
        operand_n := (instruction and $000f);
end;

function operand_nn: integer;
begin
        operand_nn := (instruction and  $00ff);
end;

function operand_nnn: integer;
begin
        operand_nnn := (instruction and $0fff);
end;

function operand_x: integer;
begin
        operand_x := (instruction and $0f00) shr 8;
end;

function operand_y: integer;
begin
        operand_y := (instruction and $00f0) shr 4;
end;

procedure input_routine;
var t: longint;
begin
         if (KeyPressed) then
         begin
               t:= get_key;
               if (t>= 0) then
                keys[t] := true;
         end;

end;

procedure fetch;
var b1, b2: integer;
begin
        b1 := memory[program_counter];
        b2 := memory[program_counter + 1];

        instruction := (b1 shl 8) or b2;
end;

procedure iterate_pc;
begin
        program_counter := program_counter + instruction_byte;
end;

function stack_pull: integer;
begin
        stack_pointer := stack_pointer - 1;
        exit(stack[stack_pointer + 1]);
end;

procedure stack_push(data: integer);
begin
        stack[stack_pointer + 1] := data;
        stack_pointer := stack_pointer + 1;
end;

procedure i0nnn;
begin
        iterate_pc;
end;

procedure i00e0;
var i: integer;
begin
        for i:=0 to graphic_size-1 do
                graphics[i]:=0;

        should_draw := true;
        iterate_pc;

end;

procedure i00ee;
begin
        program_counter := stack_pull;
        iterate_pc;
end;

procedure i1nnn;
begin
        program_counter := operand_nnn;
end;

procedure i2nnn;
begin
        stack_push(program_counter);
        program_counter:= operand_nnn;
end;

procedure i3xnn;
begin
        if (registers[operand_x] = operand_nn) then
                iterate_pc;

        iterate_pc;
end;

procedure i4xnn;
begin
        if (registers[operand_x] <> operand_nn) then
                iterate_pc;

        iterate_pc;
end;

procedure i5xy0;
begin
        if (registers[operand_x] = registers[operand_y]) then
                iterate_pc;

        iterate_pc;
end;

procedure i6xnn;
begin
        registers[operand_x] := byte(operand_nn);
        iterate_pc;
end;

procedure i7xnn;
begin

        registers[operand_x] := byte(registers[operand_x] + operand_nn);
        iterate_pc;
end;

procedure i8xy0;
begin
        registers[operand_x] := registers[operand_y];
        iterate_pc;
end;

procedure i8xy1;
begin
        registers[operand_x] := byte(registers[operand_x] or registers[operand_y]);
        iterate_pc;
end;

procedure i8xy2;
begin
        registers[operand_x] := byte(registers[operand_x] and registers[operand_y]);
        iterate_pc;
end;

procedure i8xy3;
begin
        registers[operand_x] := byte(registers[operand_x] xor registers[operand_y]);
        iterate_pc;
end;

procedure i8xy4;
begin
        if $ff - registers[operand_x] < registers[operand_y] then
                registers[$f] := 1
        else
                registers[$f] := 0;

        registers[operand_x] := byte(registers[operand_x] + registers[operand_y]);
        iterate_pc;
end;

procedure i8xy5;
begin
        if registers[operand_x] < registers[operand_y] then
                registers[$f] := 0
        else
                registers[$f] := 1;

        registers[operand_x] := byte(registers[operand_x] - registers[operand_y]);
        iterate_pc;
end;

procedure i8xy6;
begin
        registers[$f] := registers[operand_x] and $1;
        registers[operand_x] := byte(registers[operand_x] shr 1);
        iterate_pc;
end;

procedure i8xy7;
begin
        if registers[operand_x] < registers[operand_y] then
                registers[$f] := 1
        else
                registers[$f] := 0;

        registers[operand_x] := byte(registers[operand_y] - registers[operand_x]);
        iterate_pc;
end;

procedure i8xye;
begin
        registers[$f] := byte(registers[operand_x] shr 7);
        registers[operand_x] := byte(registers[operand_x] shl 1);
        iterate_pc;
end;

procedure i9xy0;
begin
        if (registers[operand_x] <> registers[operand_y]) then
              iterate_pc;

        iterate_pc;
end;

procedure iannn;
begin
        index_register := operand_nnn;
        iterate_pc;
end;

procedure ibnnn;
begin
        program_counter := operand_nnn + registers[0];
end;

procedure icxnn;
begin
        randomize;
        registers[operand_x] := operand_nn and random(256);
        iterate_pc;
end;

procedure idxyn;
var x, y, height, i, j, data, temp: integer;
    pos: longint;
begin
     x:= registers[operand_x];
     y:= registers[operand_y];
     height:= operand_n;

     registers[$f] := 0;

     for i:= 0 to height-1 do
     begin
          data:= memory[index_register + i];

          for j:= 0 to sprite_width-1 do
          begin
                if (data and ($80 shr j) > 0) then
                begin
                           pos:= x + j + ((y + i) * graphic_width);

                           if (pos < $800) then
                           begin
                                if (graphics[pos] > 0) then
                                        registers[$f] := 1;

                                graphics[pos] := graphics[pos] xor 1;
                           end;
                end;
          end;
     end;

     should_draw := true;
     iterate_pc;
end;

procedure iex9e;
begin
        if keys[registers[operand_x]] then
        begin
                keys[registers[operand_x]] := false;
                iterate_pc;
        end;

        iterate_pc;
end;

procedure iexa1;
begin
        if keys[registers[operand_x]] <> true then
        begin
                iterate_pc;
        end;

        keys[registers[operand_x]] := false;
        iterate_pc;
end;

procedure ifx07;
begin
        registers[operand_x]:= delay_timer;
        iterate_pc;
end;

procedure ifx0a;
begin
        registers[operand_x] := get_key;
        iterate_pc;
end;

procedure ifx15;
begin
        delay_timer:= registers[operand_x];
        iterate_pc;
end;

procedure ifx18;
begin
        sound_timer := registers[operand_x];
        iterate_pc;
end;

procedure ifx1e;
begin
        index_register := index_register + registers[operand_x];
        iterate_pc;
end;

procedure ifx29;
begin
        index_register := registers[operand_x] * $5;
        iterate_pc;
end;

procedure ifx33;
var x: integer;
begin
        x:= operand_x;
        memory[index_register] := registers[x] div 100;
        memory[index_register+1] := (registers[x] div 10) mod 10;
        memory[index_register+2] := registers[x] mod 100;

        iterate_pc;
end;

procedure ifx55;
var x, i: integer;
begin
        x := operand_x;

        for i:=0 to x do
        begin
                memory[index_register + i] := registers[i];
        end;

        iterate_pc;

end;


procedure ifx65;
var x, i: integer;
begin
        x := operand_x;

        for i:=0 to x do
        begin
                 registers[i]:= memory[index_register + i];
        end;

        iterate_pc;
end;

procedure load_font;
var data: array[0..79] of integer = ($f0, $90, $90, $90, $f0,
                $20, $60, $20, $20, $70,
                $f0, $10, $f0, $80, $f0,
                $f0, $10, $f0, $10, $f0,
                $90, $90, $f0, $10, $10,
                $f0, $90, $f0, $10, $f0,
		$F0, $80, $F0, $90, $F0,
		$F0, $10, $20, $40, $40,
		$F0, $90, $F0, $90, $F0,
		$F0, $90, $F0, $10, $F0,
		$F0, $90, $F0, $90, $90,
		$E0, $90, $E0, $90, $E0,
		$F0, $80, $80, $80, $F0,
                $E0, $90, $90, $90, $E0,
                $F0, $80, $F0, $80, $F0,
		$F0, $80, $F0, $80, $80);
    i: integer;
begin
        for i:=0 to 79 do
                memory[$50 + i] := data[i];
end;

procedure invaild;
begin
        clrscr;
        writeln('                               The ROM has invaild instruction. Corrupted or not a Chip8 game!! Try again!!');

        readln;
end;

procedure decode;
begin

        case (instruction and $f000) of
                $0000:
                begin
                      case (operand_nn) of
                        $00e0: i00e0;
                        $00ee: i00ee;
                        else i0nnn;
                      end;
                end;

                $1000: i1nnn;
                $2000: i2nnn;
                $3000: i3xnn;
                $4000: i4xnn;
                $5000:
                begin
                        case (instruction and $000f) of
                                $0000: i5xy0;
                                else invaild;
                        end;
                end;

                $6000: i6xnn;
                $7000: i7xnn;
                $8000:
                        case (instruction and $000f) of
                                $0000: i8xy0;
                                $0001: i8xy1;
                                $0002: i8xy2;
                                $0003: i8xy3;
                                $0004: i8xy4;
                                $0005: i8xy5;
                                $0006: i8xy6;
                                $0007: i8xy7;
                                $000e: i8xye;
                                else invaild;
                        end;

                $9000:
                        begin
                                case (instruction and $000f) of
                                        $0000: i9xy0;
                                        else invaild;
                                end;
                        end;

                $a000: iannn;
                $b000: ibnnn;
                $c000: icxnn;
                $d000: idxyn;
                $e000:
                        begin
                                case (instruction and $00ff) of
                                        $009e: iex9e;
                                        $00a1: iexa1;
                                        else invaild;
                                end;
                        end;

                $f000:
                        begin
                                case (instruction and $00ff) of
                                        $0007: ifx07;
                                        $000a: ifx0a;
                                        $0015: ifx15;
                                        $0018: ifx18;
                                        $001e: ifx1e;
                                        $0029: ifx29;
                                        $0033: ifx33;
                                        $0055: ifx55;
                                        $0065: ifx65;
                                        else invaild;
                                end;
                        end;


        end;
end;


procedure draw;
var pixel1, pixel2, x, y, symbol, i: integer;
begin
        x:=0; y:= 0;
        should_draw := false;

        while y < graphic_height do
        begin
                gotoxy(9, 5 + (y div 2));

                for x:= 0 to graphic_width - 1 do
                begin
                        i := graphic_width * y + x;

                        pixel1 := graphics[i];
                        pixel2 := graphics[i + graphic_width];

                        if (pixel1 > 0) and (pixel2 > 0) then
                                symbol := char_whole
                        else if (pixel1 > 0) then
                                symbol := char_top
                        else if (pixel2 > 0) then
                                symbol := char_bottom
                        else
                                symbol := char_space;

                        putch(symbol);
                end;

                inc(y, 2);
        end;

        if (frequency > 0) then
                delay(1000 div frequency);
end;

procedure update;
begin
        input_routine;

        if (delay_timer > 0) then
                dec(delay_timer);

        if (sound_timer > 0) then
        begin
                dec(sound_timer);

                if sound_timer = 0 then
                        putch(7);
        end;

        if should_draw then
                draw;
end;

procedure cycle;
begin
        while running do
        begin
                fetch;
                decode;
                update;
        end;
end;

procedure load_rom(path: string);
var f: file of byte;
    t: byte;
    i: integer;
begin
         if (FileExists(path)) then
         begin
                assign(f, path);
                reset(f);

                i:=0;

                while not eof(f) do
                begin
                        read(f, t);
                        memory[start_address + i] := t;

                        inc(i);
                end;


                close(f);
                clrscr;
                cycle;
         end
         else
         begin
                writeln('                               File does not exists, try again!!!');
                readln;
         end;

end;

procedure file_input_display;
begin
         frequency := -1;
         running:=true;
         should_draw := false;
         program_counter:=start_address;
         fillchar(graphics, sizeof(graphics), 0);

         clrscr;
         writeln('                               -------------------Thus CHIP8E---------------------');
         writeln('                               -To exit, Press Esc, To Continue, Press other keys-');
         writeln;

         while Not KeyPressed do;

         if ord(ReadKey) = key_esc then
         begin
              exitop := true;
         end
         else
         begin
                write('                               ROM Path: ');
                readln(rom_path);
                write('                               Frequency (Use -1 if unuse): ');
                readln(frequency);

                cursoroff;
                load_font;
                load_rom(rom_path);
                cursoron;
         end;
end;

begin
         while not exitop do
                file_input_display;
end.
