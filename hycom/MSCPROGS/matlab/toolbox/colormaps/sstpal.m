function J=sstpal(nbase)
% SSTPAL color table
%
%  Similar to the color table used by Rainer Bleck 
%  Can be found in most of the NCAR-based tools of hycom
%

if nargin < 1
   nbase = size(get(gcf,'colormap'),1);
end

rgb = [ ...
       24, 1,30;  18, 1,30;  14, 1,30;  10, 1,30;   1, 1,30;   1, 1,28; ...
        1, 1,26;   1, 1,24;   1, 1,22;   1, 1,19;   1, 4,15;   1, 7,13; ...
        1,10,13;   1,13,14;   1,12,15;   1,13,19;   1,15,20;   1,17,20; ...
        1,19,21;   1,21,21;   1,23,23;   1,25,25;   1,27,27;   1,28,28; ...
        1,29,29;   1,30,30;   1,30,27;   1,29,25;   1,29,18;   1,28,14; ...
        1,27,15;   1,25,15;   1,23,14;   1,22,10;   1,20,10;   1,18,10; ...
        1,16,10;   1,18, 7;   1,17, 1;   7,19, 1;   7,21, 1;   9,23, 1; ...
       11,25, 1;  14,26, 1;  17,27, 1;  20,28, 1;  24,29, 1;  29,29, 1; ...
       28,28, 1;  28,26, 1;  28,23, 1;  28,20, 1;  28,17, 1;  28,14, 1; ...
       28,11, 1;  28, 8, 1;  28, 5, 1;  27, 1, 1;  25, 1, 1;  22, 1, 1; ...
       19, 1, 1;  16, 1, 1;  13, 1, 1;   1, 1, 1   ];

rgb=rgb';
%size(rgb)
ncol=size(rgb,2);
scale=.03125;


J=[];
for i=1:nbase
   rind=(ncol-1)*(i-1)/(nbase-1);
   l0=min(floor(rind)+1,ncol-1);
   l1=l0+1;
   w0=l1-1-rind;
   w1=1.-w0;

   r=scale*(w0*rgb(1,l0)+w1*rgb(1,l1));
   g=scale*(w0*rgb(2,l0)+w1*rgb(2,l1));
   b=scale*(w0*rgb(3,l0)+w1*rgb(3,l1));
   J=[J ; r g b];
end
