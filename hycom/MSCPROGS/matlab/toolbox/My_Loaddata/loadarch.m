function [fld,lon,lat,depths]=loaddaily(pakfile,varname,layer1,layer2);
%function [fld,lon,lat,depths]=loaddaily(pakfile,varname,layer1,layer2);
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Routine loaddaily:
%%%%%%%%%%%%%%%%%
%This routine reads data from 4-byte big-endian daily average files (.ab - files)
%The filename and the name of the variable is supplied
%as arguments. Also, the user must supply a layer argument to the routine. 
%For 3D vars, the layer is the model layer. For 2D vars, the layer must
%be equal to 0. You can also specify a range of layers by specifying 
%the first and last layer to be read.
%
%The routine also tries to read the depths from the model depths-file
%and lon/lat from the file newpos.uf. If these files are absent, the
%fields lon,lat and/or depths will be empty.
%
%NB: If you are unsure of the name of the field you wish to extract, there is a
%list mode, see examples below.
%
%Examples: 
% 
%To read Salinity for layer 1 from the file  N32DAILY_1958_000_1958_000.[ab], three approaches:
%[fld,lon , lat, depths]=loaddaily('N32DAILY_1958_000_1958_000.b','saln',1);   
%-- or --
%[fld,lon , lat, depths]=loaddaily('N32DAILY_1958_000_1958_000.b','saln',1,1);
%fld=loaddaily('N32DAILY_1958_000_1958_000.b','saln',1,1); % Skips lon/lat/depths
%
%To read temperature for layer 1 to 3 from the file  N32DAILY_1958_000_1958_000.[ab]:
%[fld,lon , lat, depths]=loaddaily('N32DAILY_1958_000_1958_000.b','temp',1,3);
% 
%To read SSH (2-Dimensional variable) from the file  N32DAILY_1958_000_1958_000.[ab]:
%[fld,lon , lat, depths]=loaddaily('N32DAILY_1958_000_1958_000.b','ssh',1);
%
% There is also a list mode, which shows the variables in the file, example:
%[fld,lon , lat, depths]=loaddaily('N32DAILY_1958_000_1958_000.b','list');
%
%
%Knut Liseter, 17.08.2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%dir='';
dir='/cluster/work/users/annettes/NATa1.00/topo/';


lon=[];lat=[];
depths=[];
fld=[];
onem=9806;
listmode=0;

if (nargin==2 & strcmp(varname,'list'))
   listmode=1;
   layer1=1;
   layer2=1;
elseif (nargin==3)
   layer2=layer1;
elseif (nargin~=4  )
   disp(['loadpak needs 3 or 4 input  arguments']);
   %disp(['loadpak needs      4 output arguments']);
   return
end

% layer index
layerind=layer1:1:layer2;
layermatch=zeros(prod(size(layerind)),1);
layerind_file=zeros(prod(size(layerind)),1);



% Convert name if necessary
i=findstr(pakfile,'.a')-1;
if (~isempty(i))
   pakfile=pakfile(1:i);
end
i=findstr(pakfile,'.b')-1;
if (~isempty(i))
   pakfile=pakfile(1:i);
end

%disp(['Opening header file ' dir pakfile '.b']);
fid=fopen([pakfile '.b']);
if (fid~=-1)


   for k=1:6
      A=fgetl(fid);
   end

   %Yearflag
   A=fgetl(fid);
   yrflag=sscanf(A,'%d');

   %idm
   A=fgetl(fid);
   idm=sscanf(A,'%d');

   %jdm
   A=fgetl(fid);
   jdm=sscanf(A,'%d');

   A=fgetl(fid);
   
   aindex=1;
   match=0;
   %Read until match
   while (~match | listmode)
      

      A=fgetl(fid);
      if (A==-1) 
         if (~listmode)
            disp([ 'Could not find wanted variable ' varname ])
            disp([ 'Use List mode to get list of variables'  ])
         end
         return
      end

      fldid=A(1:8);
      fldidtmp=fldid;
%      fldid=strtrim(fldid);
      fldid=strtok(fldid);
      A=A(11:prod(size(A)));
      tst=sscanf(A,'%f');
      nstep=tst(1);
      dtime=tst(2);
      layer=tst(3);
      dens=tst(4);
      bmin=tst(5);
      bmax=tst(6);
      %disp([ fldid ' ' num2str(layer) ' ' num2str(match) ' ' num2str(dpmatch)]);

      if (listmode)
         S=[ 'Variable name :' fldidtmp ' layer: ' num2str(layer) ];
         disp(S);
      end

      % Get field(s)
      if (strcmp(fldid,varname))
         ind=layer-layer1+1;
         if (ind>0 & ind <= layer2-layer1+1)
            %disp(['var:' num2str(ind) ' ' num2str(layer) ' ' fldid]);
            layerind_file(ind)=aindex;
            layermatch(ind)=1;
         end
         if (sum(layermatch)==prod(size(layermatch)))
            match=1;
         end 
      end

      aindex=aindex+1;
   end

   fclose(fid);
else
   disp(['Error - could not read header file - I quit'])
   return
end

%disp(['Opening data file ' pakfile '.a' ]);
% A quirk of the mod_za module, data is dumped containing a whole multiple of 4096 values.
% This is used to skip to the correct record, but we will only read idm*jdm values...
n2drec=floor((idm*jdm+4095)/4096)*4096;
bytes_per_float=4;
fid=fopen([pakfile '.a'],'r','ieee-be'); % Big-endian

%layerind_file

% Skip to indices in layerind_file
fld=zeros(prod(size(layerind_file)),idm,jdm);
for i=1:prod(size(layerind_file))
   stat=fseek(fid,n2drec*bytes_per_float*(layerind_file(i)-1),'bof'); % Skip to corr record
   fldtmp=fread(fid,[idm jdm],'single');
   %size(fldtmp)
   %imagesc(fldtmp./avecount)

   fld(i,:,:)=fldtmp;
end
fclose(fid);


if (size(fld,1)==1) 
   fld=reshape(fld,size(fld,2),size(fld,3));
end


if (nargout>2)
   % Try to retrieve lon/lat from newpos.uf
       fid=fopen([dir 'newpos.uf'],'r','ieee-be');
   if (fid~=-1)
      stat=fseek(fid,4,'bof'); % Skip fortran 4-byte header 
      lat=fread(fid,[idm jdm],'double');
      lon=fread(fid,[idm jdm],'double');
      %contourf(lon)
      fclose(fid);
   else
      try
        [lon]=loada([dir 'regional.grid.a'],1,idm,jdm);
        [lat]=loada([dir 'regional.grid.a'],2,idm,jdm);
      catch
        disp(['newpos.uf not found -- lon lat will be empty']);
        lon=[];
        lat=[];
      end
   end
end

if (nargout>1)
  fdepths=[dir 'depths' num2str(idm,'%3.3i') 'x' num2str(jdm,'%3.3i') '.uf'];
  fid=fopen([dir 'depths' num2str(idm,'%3.3i') 'x' num2str(jdm,'%3.3i') '.uf'], ...
	  'r','ieee-be');
  if (fid~=-1)
    stat=fseek(fid,4,'bof'); % Skip fortran 4-byte header 
    depths=fread(fid,[idm jdm],'double');
    fclose(fid);
  else
     try
       [depths]=loada([dir 'depth_NATa1.00_01.a'],1,idm,jdm);
      catch
      disp([fdepths ' not found -- depths will be empty']);
depths=[];
      end
   end
end

