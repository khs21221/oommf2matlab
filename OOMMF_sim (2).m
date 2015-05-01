% Class for processing results of OOMMF simulations
% It was developed based on experience of using of OOMMF_result
classdef OOMMF_sim < hgsetget % subclass hgsetget
 
 properties
   fName = ''  
   folder = ''; % path to folder with mat files
   meshunit = 'm';
   meshtype = 'rectangular';
   xbase
   ybase
   zbase
   xnodes
   ynodes
   znodes
   xstepsize = 0.001;
   ystepsize = 0.001;
   zstepsize = 0.001;
   xmin = 0;
   ymin = 0;
   zmin = 0;
   xmax = 0.01;
   ymax = 0.01;
   zmax = 0.01;
   dim = 3;
   Mraw
   H
   totalSimTime % total simulation time
   iteration
   memLogFile = 'log.txt';
   dt = 2e-11; % time step of simulation
 end
 
 methods
   function obj = OOMMF_sim()
         disp('OOMMF_sim object was created');
   end
   
   function loadFile(obj,varargin)
       %% open file and check errors
     
     p = inputParser;
     p.addParamValue('showMemory',false,@islogical);
     p.parse(varargin{:});
     params = p.Results;
     
     if (~strcmp(obj.fName,''))
       fName = strcat(obj.fName,'.omf');
     else
       [fName,fPath,~] = uigetfile({'*.omf'; '*.stc'});
       fName = fullfile(fPath,fName);  
     end    
     
     fid = fopen(fName);
     if ((fid == -1))
       disp('File not found');
       return;
     end
     
     expr = '^#\s([\w\s:]+):\s([-.0-9e]+)';
     
     [IOmess, errnum] = ferror(fid);
     if (errnum ~= 0)
       disp(IOmess);
       return;
     end
    % read file
     propertiesList = fieldnames(obj);
     line = fgetl(fid); 
     while (isempty(strfind(line,'Begin: Data Binary')))   
       line = fgetl(fid);
       [~, ~, ~, ~, tokenStr, ~, splitStr] = regexp(line,expr);  
       % read parameters
       if (size(tokenStr,1)>0)
       if (size(tokenStr{1,1},2)>1)
          % seek properties
         toks = tokenStr{1,1};
         
         if (strcmp(toks{1,1},'Desc:  Iteration'))
           obj.iteration = str2num(toks{1,2}); 
         elseif (strcmp(toks{1,1},'Desc:  Total simulation time'))
           obj.totalSimTime = str2num(toks{1,2}); 
         else
           for i=1:size(propertiesList,1)
              if(strcmp(propertiesList{i,1},toks{1,1}))
                prop = toks{1,1};
                val = toks{1,2};
              
                %  Is it numerical value?
                [num,status] = str2num(val);
                if (status) % yes, it's numerical
                  set(obj,prop,num) 
                else % no, it's string
                    set(obj,prop,val)
                end    
              end    
           end
         end
       end          
      end    
     end
 
     % determine file format
     format='';
     if (~isempty(strfind(line,'8')))
       format = 'double';
       testVal = 123456789012345.0;
     elseif (~isempty(strfind(line,'4')))
       format = 'single';
       testVal = 1234567.0;
     else
       disp('Unknown format');
       return
     end    
     
    % read first test value
    fTestVal = fread(fid, 1, format, 0, 'ieee-le');
    if (fTestVal == testVal)
      disp('Correct format')
    else
      disp('Wrong format');
      return;
    end   
     
    data = fread(fid, obj.xnodes*obj.ynodes*obj.znodes*obj.dim,...
         format, 0, 'ieee-le');
    
    if (isempty(strfind(fgetl(fid),'# End: Data')) || isempty(strfind(fgetl(fid),'# End: Segment')))
      disp('End of file is incorrect. Something wrong');
      fclose(fid);
      return;
    else    
      fclose(fid);
    end
    
    % Mag(x y z dim)
    Mraw = reshape(data,[obj.dim obj.znodes*obj.ynodes*obj.xnodes]);
    Mraw = permute(Mraw,[2 1]); % <-- fine
    obj.Mraw = reshape(Mraw, [obj.xnodes, obj.ynodes, obj.znodes, obj.dim]);
    data =[];
    Mraw = [];
    if (params.showMemory)
      disp('Memory used:');
      memory
    end  
    disp('OMF file has been read. Size of data array is:')
    disp(size(obj.Mraw));
   end
   
   % plot 3D vector plot of magnetisation 
   function plotM3D(obj)
       MagX = squeeze(obj.M(:,:,:,1));
       MagY = squeeze(obj.M(:,:,:,2));
       MagZ = squeeze(obj.M(:,:,:,3));
       if (obj.dim==3)
         [X,Y,Z] = meshgrid(...
             obj.xbase:obj.xstepsize:(obj.xbase+obj.xstepsize*(obj.xnodes-1)),...
             obj.ybase:obj.ystepsize:(obj.ybase+obj.ystepsize*(obj.ynodes-1)),...
             obj.zbase:obj.zstepsize:(obj.zbase+obj.zstepsize*(obj.znodes-1))...
             );
         quiver3(X,Y,Z,MagX,MagY,MagZ);          
       end
   end
   
   % plot vector plot of magnetisation in XY plane
   % z is number of plane
   function plotMSurfXY(obj,slice,proj,varargin)
     p = inputParser;
     p.addRequired('slice',@isnumeric);
     p.addRequired('proj',@ischar);
     
     p.addParamValue('saveImg',false,@islogical);
     p.addParamValue('saveImgPath','');
     p.addParamValue('colourRange',0,@isnumeric);
     p.addParamValue('showScale',true,@islogical);
     p.addParamValue('xrange',':',@isnumeric);
     p.addParamValue('yrange',':',@isnumeric);
     
     p.parse(slice,proj,varargin{:});
     params = p.Results;
       
     handler = obj.abstractPlot('Z',params.slice,params.proj,...
         'saveImg',params.saveImg,'saveImgPath',params.saveImgPath,...
         'colourRange',params.colourRange,'showScale',params.showScale,...
         'xrange',params.xrange,'yrange',params.yrange);                  
   end
   
   % plot vector plot of magnetisation in XY plane
   % z is number of plane
   function plotMSurfXZ(obj,slice,proj,varargin)
     p = inputParser;
     p.addRequired('slice',@isnumeric);
     p.addRequired('proj',@ischar);
     
     p.addParamValue('saveImg',false,@islogical);
     p.addParamValue('saveImgPath','');
     p.addParamValue('colourRange',0,@isnumerical);
     p.addParamValue('showScale',true,@islogical);
     p.addParamValue('xrange',0,@isnumerical);
     p.addParamValue('yrange',0,@isnumerical);
     
     p.parse(slice,proj,varargin{:});
     params = p.Results;
       
     handler = obj.abstractPlot('Y',params.slice,params.proj,...
         'saveImg',params.saveImg,'saveImgPath',params.saveImgPath,...
         'colourRange',params.colourRange,'showScale',params.showScale);                  
   end
   
   % plot vector plot of magnetisation in XZ plane
   % z is number of planex
   function plotMSurfYZ(obj,slice,proj,varargin)
     p = inputParser;
     p.addRequired('slice',@isnumeric);
     p.addRequired('proj',@ischar);
     
     p.addParamValue('saveImg',false,@islogical);
     p.addParamValue('saveImgPath','');
     p.addParamValue('colourRange',0,@isnumeric);
     p.addParamValue('showScale',true,@islogical);
     p.addParamValue('rotate',false,@islogical);
     p.addParamValue('substract',false,@islogical);
     p.addParamValue('background',0,@isnumeric);
     p.addParamValue('xrange',':',@isnumeric);
     p.addParamValue('yrange',':',@isnumeric);
     
     p.parse(slice,proj,varargin{:});
     params = p.Results;
       
     handler = obj.abstractPlot('X',params.slice,params.proj,...
         'saveImg',params.saveImg,'saveImgPath',params.saveImgPath,...
         'colourRange',params.colourRange,'showScale',params.showScale,...
         'rotate',params.rotate,'substract',params.substract,...
         'background',params.background,'xrange',params.xrange,...
         'yrange',params.yrange); 
   end
   
   % base function for surface plot
   % viewAxis   -  view along: 1 - X axis, 2 - Y axis, 3 - Z axis
   % slice -  slice number
   % proj  -  projection: 1 - Mx, 2 - My, 2 - Mz
   % saveImg  -  save img (booleans)
   % saveImgPath - path to save image 
   function handler = abstractPlot(obj,viewAxis,slice,proj,varargin)
    
     % parse input parameters
     p = inputParser;
     p.addRequired('viewAxis',@ischar);
     p.addRequired('slice',@isnumeric);
     p.addRequired('proj',@ischar);
     p.addParamValue('saveImg', false,@islogical);
     p.addParamValue('saveImgPath','');
     p.addParamValue('colourRange',0,@isnumeric);
     p.addParamValue('showScale',true,@islogical);
     p.addParamValue('xrange',:);
     p.addParamValue('yrange',:);
     p.addParamValue('rotate',false,@islogical);
     p.addParamValue('substract',false,@islogical);
     p.addParamValue('background',0,@isnumeric);
     
     p.parse(viewAxis,slice,proj,varargin{:});
     params = p.Results;
    
     switch (obj.getIndex(params.viewAxis)) 
         case 1
             axis1 = 'Y ';
             axis2 = 'Z ';
         case 2
             axis1 = 'X ';
             axis2 = 'Z ';
         case 3
             axis1 = 'X ';
             axis2 = 'Y ';
         otherwise
             disp('Unknows projection');
             return
     end        
              
    data = obj.getSlice(params.viewAxis,params.slice,params.proj,...
        'range1',params.xrange,'range2',params.yrange);        
    if (params.substract)
       if (prod(size(data) == size(params.background)))
          data = data - params.background; 
       else
          disp('Size of background array mismatches size of image'); 
       end    
    end    
     
    if (params.colourRange == 0)
	   maxM = max(max(data(:)),abs(min(data(:))));
       base = fix(log10(maxM));
       t1 = ceil(maxM/(10^base));
       t2 = 10^base;
       params.colourRange = t1*t2;
    
       if (isnan(params.colourRange))
         params.colourRange = 100;
         disp('Colour range is undefined');
       end
    else
         
    end
    
    G = fspecial('gaussian',[3 3],0.9);
    %G = fspecial('average',7);
    if (params.rotate)
      data =  data.';
      tmp = axis1;
      axis1=axis2;
      axis2=tmp;
    end
        
    Ig = imfilter(data,G,'circular','same','conv');
	handler = imagesc(Ig, [-500 500]);
	axis xy;
    
    colormap(b2r(-params.colourRange,params.colourRange));
    %colormap(copper);
    
	hcb=colorbar('EastOutside');
	set(hcb,'XTick',[-params.colourRange,0,params.colourRange]);
    
    if (params.showScale)
      xlabel(strcat(axis1,'(\mum)'), 'FontSize', 10);
      ylabel(strcat(axis2,' (\mum)'), 'FontSize', 10);
      set(gca,'XTick',[1,...
                     ceil((1+eval(strcat('obj.',lower(axis1),'nodes')))/2),...
                     eval(strcat('obj.',lower(axis1),'nodes'))],...
              'XTickLabel',[eval(strcat('obj.',lower(axis1),'min'))/1e-6,...
                      0.5*(eval(strcat('obj.',lower(axis1),'min'))+eval(strcat('obj.',lower(axis1),'max')))/1e-6,...
                      eval(strcat('obj.',lower(axis1),'max'))/1e-6]);
                  
      set(gca,'YTick',[1,...
                     ceil((1+eval(strcat('obj.',lower(axis2),'nodes')))/2),...
                     eval(strcat('obj.',lower(axis2),'nodes'))],...
              'YTickLabel',[eval(strcat('obj.',lower(axis2),'min'))/1e-6,...
                      0.5*(eval(strcat('obj.',lower(axis2),'min'))+eval(strcat('obj.',lower(axis2),'max')))/1e-6,...
                      eval(strcat('obj.',lower(axis2),'max'))/1e-6]);
    else
      axis([0,size(data,2),0,size(data,1)]);
      xlabel(strcat(axis1,'(cell #)'), 'FontSize', 10);
      ylabel(strcat(axis2,' (cell #)'), 'FontSize', 10);
    end

     % set X limit 
 %   if (~strcmp(params.xrange,':'))
 %     if (params.rotate) 
 %       ylim(params.xrange);
 %     else
 %       xlim(params.xrange);  
 %     end    
 %   end    
    
     % set Y limit 
 %   if (~strcmp(params.yrange,':'))
 %     if (params.rotate) 
 %       xlim(params.yrange);
 %     else
 %       ylim(params.yrange);  
 %     end
 %   end    
    
                  
	set(hcb,'FontSize', 15);
    title(strcat('view along ',viewAxis,' axis, M',params.proj,' projection',...
                  ', simulation time = ',num2str(obj.totalSimTime,'%10.2e'),' s'));
    if (params.saveImg)
      imgName = strcat(params.saveImgPath,'\',...
                       'Image_Along',viewAxis,...
                       '_Slice',num2str(slice),...
                       '_M',lower(params.proj),...
                       '_iter',num2str(obj.iteration),...
                       '.png');
	  saveas(handler, imgName);
    end   
    clear data;
   end
   
     % scan folder, load all *.omf files, save objects
   % path - path to the folder
   % saveObj - save an objects?
   % savePath - path to save objects 
   function scanMFolder(obj,path,varargin) 
     % parse input parameters
     p = inputParser;
     p.addRequired('path',@ischar);
     p.addParamValue('deleteFiles', false,@islogical);
     p.addParamValue('showMemory',false,@islogical);
     p.addParamValue('makeFFT',false,@islogical);
     p.addParamValue('fileBase','',@isstr);
     p.addParamValue('savePath','',@isstr);
     
     p.parse(path,varargin{:});
     params = p.Results;
     
     if strcmp(params.savePath,'')
         savePath = path;
     else
         savePath = params.savePath; 
     end
     
                
     fList = obj.getFilesList(path,params.fileBase,'omf');     
     file = fList(1);
     [~, fName, ~] = fileparts(file.name);
     pt = strcat(path,'\',fName);
     obj.fName = pt;
     obj.loadFile('showMemory',params.showMemory);
     save(strcat(savePath,'\params.mat'), 'obj');
     
     % create files and variables   
     Mx = zeros(size(fList,1),obj.xnodes,obj.ynodes,obj.znodes);
     My = zeros(size(fList,1),obj.xnodes,obj.ynodes,obj.znodes);
     Mz = zeros(size(fList,1),obj.xnodes,obj.ynodes,obj.znodes);
     
     for i=2:size(fList,1)
       disp (i)  
       file = fList(i);
       [~, fName, ~] = fileparts(file.name);
       pt = strcat(path,'\',fName);
       obj.fName = pt;
       obj.loadFile('showMemory',params.showMemory);
       
       Mx(i,:,:,:) = obj.Mraw(:,:,:,1);
       My(i,:,:,:) = obj.Mraw(:,:,:,2);
       Mz(i,:,:,:) = obj.Mraw(:,:,:,3);
       
       if (params.deleteFiles)
           delete(strcat(pt,'.omf'));
       end                       
     end
     
     disp('Save Mx');
     save(fullfile(savePath,'Mx.mat'),'Mx'); 

     if (params.makeFFT)
        disp('Mx FFT'); 
        Yx = fft(Mx);  
        disp('Save Mx FFT');
        save(fullfile(savePath,'MxFFT.mat'),'Yx');
        clearvars Mx Yx   
     end     
     
     disp('Save My');
     save(fullfile(savePath,'My.mat'),'My'); 
     
     if (params.makeFFT)
        disp('My FFT');
        Yy = fft(My);
        disp('Save My FFT');
         save(fullfile(savePath,'MyFFT.mat'),'Yy');
        clearvars My Yy  
     end
     
     disp('Save Mz');
     save(fullfile(savePath,'Mz.mat'),'Mz'); 
     
     if (params.makeFFT)        
        disp('Mz FFT'); 
        Yz = fft(Mz);
        disp('Save Mz FFT');
        save(fullfile(savePath,'MzFFT.mat'),'Yz');
        clearvars Mz Yz    
     end     
   end
   
   function writeMemLog(obj,comment)
     res = memory;  
     fid = fopen(obj.memLogFile,'a');
     data = clock;
     str = strcat(num2str(data(3)),'-',num2str(data(2)),'-',num2str(data(1)),...
          '   ',num2str(data(4)),':',num2str(data(5)));
     fprintf(fid,str);
     fprintf(fid,strcat('MaxPossibleArrayBytes :', num2str(res.MaxPossibleArrayBytes),' \n'));
     fprintf(fid,strcat('MemAvailableAllArrays :',num2str(res.MemAvailableAllArrays),' \n'));
     fprintf(fid,strcat('MemUsedMATLAB :',num2str(res.MemUsedMATLAB),' \n'));
     fclose(fid);
   end    
         
   % return slice of space
   % sliceNumber
   % proj 
   % rangeX - array
   % rangeY - array
   % rangeZ - array
   function res = getSlice(obj,viewAxis,sliceNumber,proj,varargin)
     p = inputParser;
     p.addRequired('viewAxis', @(x)any(strcmp(x,{'X','Y','Z',':'})));
     p.addRequired('proj', @(x)any(strcmp(x,{'X','Y','Z',':'})));
     p.addRequired('sliceNumber',@isnumeric);
     p.addParamValue('range1',':',...
          @(x)(strcmp(x,':') ||...
          (isnumeric(x) && (size(x,1)==1) && (size(x,2)==2))...
        ));
     p.addParamValue('range2',':',...
          @(x)(strcmp(x,':') || ...
          (isnumeric(x) && (size(x,1)==1) && (size(x,2)==2))...
        ));
    
     p.parse(viewAxis,proj,sliceNumber,varargin{:});
     params = p.Results;
     params.proj = obj.getIndex(params.proj);
     
    if (isnumeric(params.range1) && (size(params.range1,1)==1) && (size(params.range1,2)==2))
       range1str = strcat(num2str(params.range1(1)),':',num2str(params.range1(2)));
    else
       range1str = ':'; 
    end    

    if (isnumeric(params.range2) && (size(params.range2,1)==1) && (size(params.range2,2)==2))
       range2str = strcat(num2str(params.range2(1)),':',num2str(params.range2(2)));
    else
        range2str = ':';
    end
    
    if (strcmp(params.viewAxis,'X'))
      ind = strcat('params.sliceNumber,',range1str,',',range2str,',params.proj');
    elseif (strcmp(params.viewAxis,'Y'))
      ind = strcat(range1str,',params.sliceNumber,',range2str,',params.proj');  
    elseif (strcmp(params.viewAxis,'Z') )
      ind = strcat(range1str,',',range2str,',params.sliceNumber,params.proj');
    else
      disp('Dimension is incorrect');
      return;
    end
    
    str = strcat('obj.Mraw(',ind,')');
    tmp = eval(str);
    if (ndims(tmp) == 2)
      res = squeeze(tmp).';
    elseif (ndims(tmp) == 3)
      res = squeeze(tmp).';
    elseif (ndims(tmp) == 4)
      res = permute(squeeze(tmp),[2 1 3 4]);  
    else
       disp('Unexpected dimension of array');
       res = false;
    end       
   end
   
   function res = getIndex(obj,symb)
   if (strcmp(symb,'X'))
      res = 1;
   elseif (strcmp(symb,'Y'))
      res = 2;
   elseif (strcmp(symb,'Z'))
      res = 3;
   elseif (strcmp(symb,':'))
      res = ':'; 
   else
      disp('Unknown index');
      return;
   end    
   end
 
   %scan folder %path% and select all %ext% files
   function fList = getFilesList(obj,path,fileBase,ext)
     if (isdir(path))
       if length(fileBase)  
           fList = dir(strcat(path,'\',fileBase,'*.',ext));
       else
           pth = strcat(path,'\*.',ext)
           fList = dir(pth);
       end    
     else
       disp('Incorrect folder path');
       return;
     end
     
     if (size(fList,1) == 0)
       disp('No suitable files');
       return;
     end
   end
   
   function res = getVolume(obj,xrange,yrange,zrange,proj)
     res = obj.Mraw(xrange,yrange,zrange,obj.getIndex(proj));  
   end 
   
   % method process results of simulations, parse files, save as arrays and
   % perform Fast Fourier Transformation
   function res = processCalcResult(obj, path,varargin)
       p = inputParser;
       p.addRequired('path',@isdir);
       p.addParamValue('fileBase','',@isstr)

       p.parse(path,varargin{:});
       params = p.Results;
 
       fList = obj.getFilesList(path,params.fileBase,'omf');

        % determine size of arrays
       tmp = load(strcat(path,'\',fList(1).name));
       obj = tmp.obj;

       Mx = zeros(size(fList,1),obj.xnodes,obj.ynodes,obj.znodes);
       My = zeros(size(fList,1),obj.xnodes,obj.ynodes,obj.znodes);
       Mz = zeros(size(fList,1),obj.xnodes,obj.ynodes,obj.znodes);

       Mx(1,:,:,:) = obj.Mraw(:,:,:,1); 
       My(1,:,:,:) = obj.Mraw(:,:,:,2);
       Mz(1,:,:,:) = obj.Mraw(:,:,:,3);

       for fInd = 2:size(fList,1)
           fPath = strcat(path,'\',fList(fInd).name);
           tmp = load(fPath);
           MxArr(fInd,:,:,:) = tmp.obj.Mraw(:,:,:,1); 
           MyArr(fInd,:,:,:) = tmp.obj.Mraw(:,:,:,2);
           MzArr(fInd,:,:,:) = tmp.obj.Mraw(:,:,:,3);
           disp(fInd);
       end
       
       disp('All files have been loaded');

       disp('Start Mx FFT');
       Yx = fft(Mx);
       disp('Save Mx FFT');
       
       save Mx.mat Mx;
       Mx = [];

       save YxFFT.mat Yx
       Yx=[];
       
       disp('Start My FFT');
       Yy = fft(My);
       disp('Save My FFT');
       My = [];
       save YyFFT.mat Yy
       Yy=[];
       
       disp('Start Mz FFT');
       Yz = fft(MzArr);
       disp('Save Mz FFT');
       Mz = [];
       save YzFFT.mat Yz
       Yz=[];
   end
   
   % Three function below return data of magnetization projection
   function res = getMx(obj,tRange,xRange,yRange,zRange)
   end
   
   function res = getMy(obj,tRange,xRange,yRange,zRange)
   end
   
   function res = getMz(obj,tRange,xRange,yRange,zRange)
   end
   
   % plot dispersion curve along X axis
   function plotDispersionX(obj,varargin)
       p = inputParser;
       p.addParamValue('xRange',:);
       p.addParamValue('yRange',:);
       p.addParamValue('zRange',:);
       p.addParamValue('scale',''); % <-------- TODO
       p.addParamValue('freqLimit','');
       p.addParamValue('waveLimit','');
       
       p.parse(varargin{:});
       params = p.Results;
       
       MzFile = matfile(fullfile(obj.folder,'Mz.mat'));
       Mz = MzFile.Mz(:,params.xRange,params.yRange,params.zRange);
       
       waveVectorScale = 2*pi*linspace(-0.5*0.5,0.5*0.5,size(Mz,2));
       [~,waveVectorInd(1)] = min(abs(waveVectorScale-params.waveLimit(1)));
       [~,waveVectorInd(2)] = min(abs(waveVectorScale-params.waveLimit(2)));
       waveVectorScale = waveVectorScale(waveVectorInd(1):waveVectorInd(2));       
       
       dt = 2e-11;                   % <-------- TODO 
       freqScale = linspace(-0.5/dt,0.5/dt,size(Mz,1))/1e9; 
       [~,freqScaleInd(1)] = min(abs(freqScale-params.freqLimit(1)));
       [~,freqScaleInd(2)] = min(abs(freqScale-params.freqLimit(2)));
       freqScale = freqScale(freqScaleInd(1):freqScaleInd(2));
  
       Yraw = fft2(Mz);
       Y = mean(Yraw,4);
       Y = mean(Yraw,3);
       
       Amp = fftshift(abs(Y));
       Amp = Amp(freqScaleInd(1):freqScaleInd(2),waveVectorInd(1):waveVectorInd(2));
       imagesc(waveVectorScale,freqScale,log10(Amp/min(Amp(:))));
       xlabel('Wave vector k, \mum^-^1'); xlim([0 max(waveVectorScale)]);
       ylabel('Frequency, GHz');
       axis xy
       
       t = colorbar('peer',gca);
       set(get(t,'ylabel'),'String', 'FFT intensity, dB');      
   end 
   
   % plot spatial map of FFT distribution for a given frequency
   function plotFFTSliceZ(obj,varargin)
       p = inputParser;
   
       p.addParamValue('freq',0,@isnumeric);
       p.addParamValue('zSlice',5,@isnumeric);
       
       p.parse(varargin{:});
       params = p.Results;
       
       % load parameters
       tmp = load(fullfile(obj.folder,'params.mat'));
       simParams = tmp.obj;
       xScale=linspace(simParams.xmin,simParams.xmax,simParams.xnodes)/1e-6;
       yScale=linspace(simParams.ymin,simParams.ymax,simParams.ynodes)/1e-6;
       zScale=linspace(simParams.zmin,simParams.zmax,simParams.znodes)/1e-6;
       
       % assign file of FFT of Mz
       MzFFTFile = matfile(fullfile(obj.folder,'MzFFT.mat'));
       
       MzFFTSize = size(MzFFTFile,'Yz');
       % create freq Scale
       freqScale = linspace(-0.5/obj.dt,0.5/obj.dt,MzFFTSize(1))/1e9;
       shiftFreqScale = ifftshift(freqScale);
       [~,freqInd] = min(abs(shiftFreqScale-params.freq));
       
       fftSlice = squeeze(MzFFTFile.Yz(freqInd,:,:,params.zSlice));
       Amp = abs(fftSlice);
       Phase = angle(fftSlice);
       
       % plot amplitude map
       subplot(2,1,1);
           imagesc(xScale,yScale,Amp.');
           title('Amplitude of FFT');
           axis xy; hcb=colorbar('EastOutside');
           set(get(hcb,'ylabel'),'String', 'a.u.');
           ylabel('Y, \mum'); xlabel('X, \mum'); 

       % plot phase map   
       subplot(2,1,2);
          imagesc(xScale,yScale,Phase.',[-pi pi]);
          title('Phase of FFT');
          axis xy; hcb=colorbar('EastOutside');
          set(get(hcb,'ylabel'),'String', 'rad.');
          ylabel('Y, \mum'); xlabel('X, \mum');
       
       
   end 
   
   % plot dependence of FFT intensity on frequency
   function plotFFTIntensity(obj,varargin)
       zFFTFile = matfile('MzFFT.mat'); 
       zFFT = zFFTFile.Yz(:,:,22:60,10);
       Y = mean(mean(zFFT,2),3);
       Amp = abs(fftshift(Y));
       
       freqScale = linspace(-0.5/obj.dt,0.5/obj.dt,size(Amp,1))/1e9;
       semilogy(freqScale,Amp);
       xlim([0 20]); xlabel('Frequency, GHz');
       ylabel('FFT intensity, a.u.');
   end
   
   % make movie
   function makeMovie(obj,varargin)
       
       p = inputParser;
       p.addParamValue('xRange',:,@isnumeric);
       p.addParamValue('zSlice',10,@isnumeric);
       p.addParamValue('timeFrames',100,@isnumeric);
       p.addParamValue('yRange',22:60,@isnumeric);
       p.addParamValue('colourRange',6000);
       
       p.parse(varargin{:});
       params = p.Results;
       
       G = fspecial('gaussian',[3 3],0.9);
       
       MzFile = matfile('Mz.mat');
       Mz = squeeze(MzFile.Mz(end-params.timeFrames : end,:,params.yRange,params.zSlice));
       
       videoFile = generateFileName('.','movie','mp4')
       writerObj = VideoWriter(videoFile);
       writerObj.FrameRate = 10;
       open(writerObj);
       
       % load parameters
       % calculate axis
       tmp = load(fullfile(obj.folder,'params.mat'));
       simParams = tmp.obj;
       xScale = linspace(simParams.xmin,simParams.xmax,simParams.xnodes)/1e-6;
       yScale = linspace(simParams.ymin,simParams.ymax,simParams.ynodes)/1e-6;
       yScale = yScale(params.yRange);
       
       fig=figure(1);
       for timeFrame = 1:size(Mz,1)
           Ig = imfilter(squeeze(Mz(timeFrame,:,:)).',G,'circular','same','conv');
           handler = imagesc(xScale,yScale,Ig);
           axis xy;
           xlabel('X, \mum'); ylabel('X, \mum'); 
           writeVideo(writerObj,getframe(fig));
 
           colormap(b2r(-params.colourRange,params.colourRange));
           %colormap(copper);
     
           hcb=colorbar('EastOutside');
           set(hcb,'XTick',[-params.colourRange,0,params.colourRange]);
       end   
       
       close(writerObj);
   end    
   
 end
end 


  %% create red-blue color map 
 function newmap = b2r(cmin_input,cmax_input)
%BLUEWHITERED   Blue, white, and red color map.
%   this matlab file is designed to draw anomaly figures, the color of
%   the colorbar is from blue to white and then to red, corresponding to 
%   the anomaly values from negative to zero to positive, respectively. 
%   The color white always correspondes to value zero. 
%   
%   You should input two values like caxis in matlab, that is the min and
%   the max value of color values designed.  e.g. colormap(b2r(-3,5))
%   
%   the brightness of blue and red will change according to your setting,
%   so that the brightness of the color corresponded to the color of his
%   opposite number
%   e.g. colormap(b2r(-3,6))   is from light blue to deep red
%   e.g. colormap(b2r(-3,3))   is from deep blue to deep red
%
%   I'd advise you to use colorbar first to make sure the caxis' cmax and cmin
%
%   by Cunjie Zhang
%   2011-3-14
%   find bugs ====> email : daisy19880411@126.com
%  
%   Examples:
%   ------------------------------
%   figure
%   peaks;
%   colormap(b2r(-6,8)), colorbar, title('b2r')
%   


%% check the input
if nargin ~= 2 ;
   disp('input error');
   disp('input two variables, the range of caxis , for example : colormap(b2r(-3,3))')
end

if cmin_input >= cmax_input
    disp('input error')
    disp('the color range must be from a smaller one to a larger one')
end

%% control the figure caxis 
lims = get(gca, 'CLim');   % get figure caxis formation
caxis([cmin_input cmax_input])

%% color configuration : from blue to light blue to white untill to red

red_top     = [1 0 0];
white_middle= [1 1 1];
blue_bottom = [0 0 1];

%% color interpolation 

color_num = 250;   
color_input = [blue_bottom;  white_middle;  red_top];
oldsteps = linspace(-1, 1, length(color_input));
newsteps = linspace(-1, 1, color_num);  

%% Category Discussion according to the cmin and cmax input

%  the color data will be remaped to color range from -max(abs(cmin_input,abs(cmax_input)))
%  to max(abs(cmin_input,abs(cmax_input))) , and then squeeze the color
%  data in order to make suere the blue and red color selected corresponded
%  to their math values

%  for example :
%  if b2r(-3,6) ,the color range is from light blue to deep red ,
%  so that the color at -3 is light blue while the color at 3 is light red
%  corresponded

%% Category Discussion according to the cmin and cmax input
% first : from negative to positive
% then  : from positive to positive
% last  : from negative to negative

newmap_all = NaN(size(newsteps,2),3);
if (cmin_input < 0)  &&  (cmax_input > 0) ;  
    
    
    if abs(cmin_input) < cmax_input 
         
        % |--------|---------|--------------------|    
      % -cmax      cmin       0                  cmax         [cmin,cmax]
      %    squeeze(colormap(round((cmin+cmax)/2/cmax),size(colormap)))
 
       for j=1:3
           newmap_all(:,j) = min(max(transpose(interp1(oldsteps, color_input(:,j), newsteps)), 0), 1);
       end
       start_point = round((cmin_input+cmax_input)/2/cmax_input*color_num);
       newmap = squeeze(newmap_all(start_point:color_num,:));
       
    elseif abs(cmin_input) >= cmax_input
        
         % |------------------|------|--------------|    
       %  cmin                0     cmax          -cmin         [cmin,cmax]
       %    squeeze(colormap(round((cmin+cmax)/2/cmax),size(colormap)))       
       
       for j=1:3
           newmap_all(:,j) = min(max(transpose(interp1(oldsteps, color_input(:,j), newsteps)), 0), 1);
       end
       end_point = round((cmax_input-cmin_input)/2/abs(cmin_input)*color_num);
       newmap = squeeze(newmap_all(1:end_point,:));
    end
    
       
elseif cmin_input >= 0

       if lims(1) < 0 
           disp('caution:')
           disp('there are still values smaller than 0, but cmin is larger than 0.')
           disp('some area will be in red color while it should be in blue color')
       end
        % |-----------------|-------|-------------|    
      % -cmax               0      cmin          cmax         [cmin,cmax]
      %    squeeze(colormap(round((cmin+cmax)/2/cmax),size(colormap)))
 
       for j=1:3
           newmap_all(:,j) = min(max(transpose(interp1(oldsteps, color_input(:,j), newsteps)), 0), 1);
       end
       start_point = round((cmin_input+cmax_input)/2/cmax_input*color_num);
       newmap = squeeze(newmap_all(start_point:color_num,:));

elseif cmax_input <= 0

       if lims(2) > 0 
           disp('caution:')
           disp('there are still values larger than 0, but cmax is smaller than 0.')
           disp('some area will be in blue color while it should be in red color')
       end
       
         % |------------|------|--------------------|    
       %  cmin         cmax    0                  -cmin         [cmin,cmax]
       %    squeeze(colormap(round((cmin+cmax)/2/cmax),size(colormap)))       

       for j=1:3
           newmap_all(:,j) = min(max(transpose(interp1(oldsteps, color_input(:,j), newsteps)), 0), 1);
       end
       end_point = round((cmax_input-cmin_input)/2/abs(cmin_input)*color_num);
       newmap = squeeze(newmap_all(1:end_point,:));
end
 end
 
 %% create greyscale color map
 function newmap = grayMap(cmin_input,cmax_input)
 end