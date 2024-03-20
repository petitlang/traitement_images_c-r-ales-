close all;
clear all;
format long g;
format compact;
fontSize = 20;
%======Importer les images======
currentPath = fileparts(mfilename('fullpath'));
path = [currentPath,'\Scanner\','*.png'];
List = dir(path);
SIZE = numel(List);

%======Creer une fenêtre======
f=figure();
set(f, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
%% Detecter la scissure cérébrale
%======Triage des images======
% Prendre une image comme référence
path = [currentPath,'\Scanner\','ct240.png'];
ImageRef = imread(path);
%Vérifier la corrélation
for i = 1:SIZE
    path = [currentPath,'\Scanner\',List(i).name];
    I = imread(path);
    R = corr2(double(ImageRef),double(I));
    if R<=1 && R>0.65 
        %======Images initiales======
        subplot(2,3,1);imshow(I);axis on;
        title(['Image initiale de ',List(i).name]);
        subplot(2,3,2:3);imhist(I);
        title(['Histogramme de ',List(i).name]);
        
        %======Seuillage pour trouver le crâne ======
        thresholdValue = 180;
        skullBW = I > thresholdValue;
        SE = strel('disk',4);
        skullBW = imopen(skullBW, SE);
        % Montrer l'image binaire
        subplot(2,4,5);imshow(skullBW);axis on;
        title('Image binaire du crâne');
        
        %======Masquez le crâne de l'image originale grise.======
        brainImage = I; % Initialiser
        brainImage(skullBW) = 0; % Masquer`
        brainBW = imbinarize(brainImage);
        SE = strel('disk',12);
        brainBW = imopen(brainBW,SE);
        brainBW = imopen(brainBW,SE);
        brainBW = bwareafilt(brainBW, 1);

        % Montrer l'image binaire du cerveau seul
        subplot(2,4,6);imshow(brainBW, []);axis on;
        title('Image binaire du cerveau');

        % Montrer l'image binaire de la tête
        headBW  = logical(skullBW + brainBW);
        headBW = imdilate(headBW, SE);
        subplot(2,4,7);imshow(headBW, []);axis on;
        title('Image binaire de la tête');

        % On sait que dans cette image, il existe une anomalie,
        % probablement tumeur. On le garde pour l'utitiliser plus tard
        brainImage (not(brainBW))= 0;
        if i==124
            tumoredBrainImage = brainImage;
        end

        %  Montrer l'image grise du cerveau seul
        brainImage = imadjust(brainImage,[100/255,150/255]);
        SE = strel('disk',1);
        brainImage = imclose(brainImage,SE);
%         subplot(2,4,7);imshow(brainImage);axis on;
%         title('Image grise ajustée du cerveau');

        %======Detecter la scissure cérébrale======
        BW = headBW;
%         BW = skullBW;
%         BW = brainBW;

        % Extracter le bulb le plus gros
        BW = imclearborder(BW);
        BW = bwareafilt(BW,1);

        % Obtenir le centre de l'ellipse, l'orientation et la longeur des axes 
        s = regionprops(BW,{'Centroid','Orientation','MajorAxisLength','MinorAxisLength'});

        % Exprimer l'ellipse posée horisontalement à l'origine
        theta = linspace(0,2*pi);
        col = (s.MajorAxisLength/2)*cos(theta);
        row = (s.MinorAxisLength/2000)*sin(theta);

        % Chasser le cas que l'ellipse s'est couchée
        if abs(s.Orientation)<10
            s.Orientation = s.Orientation+90;
        end

        % Construire une matrice de transformation pour bien localiser
        % l'ellipse
        M = makehgtform('translate',[s.Centroid, 0],'zrotate',deg2rad(-1*s.Orientation));
        D = M*[col;row;zeros(1,numel(row));ones(1,numel(row))];
        % Monter l'image du cerveau 
        subplot(2,4,8);imshow(brainImage);axis on;hold on
        plot(D(1,:),D(2,:),'r','LineWidth',2)
        title('Image grise ajustée du cerveau avec scissure notée');

        promptMessage = sprintf('Continuer ou Quitter?');
        titleBarCaption = 'Continuer?';
        buttonText = questdlg(promptMessage, titleBarCaption, 'Continuer', 'Quitter', 'Continuer');
        if strcmpi(buttonText, 'Quitter')
            return;
        end
    end 
end 

%% Détecter une tumeur
promptMessage = sprintf('Continuer à trouver la tumeur,\nou Quitter?');
titleBarCaption = 'Continuer?';
buttonText = questdlg(promptMessage, titleBarCaption, 'Continuer', 'Quitter', 'Continuer');
if strcmpi(buttonText, 'Quitter')
	return;
end
path = [currentPath,'\Scanner\','ct138.png'];
tumoredHeadImage = imread(path);

% ======Seuillage à nouveau popur trouver la tumeur======
thresholdValue = 160;
binaryImage = tumoredBrainImage > thresholdValue;
% Montrer l'image binaire seuillée.
hFig2 = figure();
subplot(2, 2, 1);
imshow(binaryImage, []);
axis on;
caption = sprintf('Image Binaire Initiale\nseuillé à %d ', thresholdValue);
title(caption, 'FontSize', fontSize, 'Interpreter', 'None');

% Elargir la figure.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.25 0.15 .5 0.7]);
% Enlever le toolbar
set(gcf, 'Name', 'Detection tumeur', 'NumberTitle', 'Off') 
drawnow;

% ======Extracter la tumeru qui est le bulb le plus gros======
binaryTumorImage = bwareafilt(binaryImage, 1);
binaryTumorImage = imdilate(binaryTumorImage,SE);
binaryTumorImage = imdilate(binaryTumorImage,SE);
binaryTumorImage = imdilate(binaryTumorImage,SE);
binaryTumorImage = imdilate(binaryTumorImage,SE);
% Montrer l'image
subplot(2, 2, 2);
imshow(binaryTumorImage, []);
axis on;
caption = sprintf('Tumeur Seule');
title(caption, 'FontSize', fontSize, 'Interpreter', 'None');

% ====== Mondalité 1 : Trouver les bords de la tumeur======
subplot(2, 2, 3);imshow(tumoredHeadImage, []);axis on;
caption = sprintf('Tumeur\nsilhouettée en rouge'); 
title(caption, 'FontSize', fontSize, 'Color', 'r'); 
axis image; % Assurez que l'image n'est pas artificiellement étirée en raison du format de l'écran.
hold on;
boundaries = bwboundaries(binaryTumorImage);
numberOfBoundaries = size(boundaries,1);
for k = 1 : numberOfBoundaries
	thisBoundary = boundaries{k};
	% Pour avoir les coordonnées x, il faut consulter la deuxième colonne
	plot(thisBoundary(:,2), thisBoundary(:,1), 'r', 'LineWidth', 2);
end
hold off;

% ====== Mondalité 2 : relever l'aire de la tumeur ======
subplot(2, 2, 4);imshow(tumoredHeadImage, []);
caption = sprintf('Tumeur\nteintée en rouge'); 
title(caption, 'FontSize', fontSize, 'Color', 'r'); 
axis image; 
hold on;
% Montrer la tumeur sur les mêmes axes 
% Construire une image revêtement RGB tout en rouge
redOverlay = cat(3, ones(size(binaryTumorImage)), zeros(size(binaryTumorImage)), zeros(size(binaryTumorImage)));
hRedImage = imshow(redOverlay); % Enregistrer cela pour l'utiliser après
hold off;
axis on;
% Masquer d'autres choses que la tumeur et modifier la transparence
alpha_data = 0.3 * double(binaryTumorImage);
set(hRedImage, 'AlphaData', alpha_data);