% Solving 2D navier stokes equation with SMAC method
% Copyright (C) 2020  T.Nakabayashi
% Released under the MIT license http://opensource.org/licenses/mit-license.php

% 初期化
clear all;

% グローバル変数宣言
global dt ne

% 変数読み込み
load('shapshot.mat')

% NaNをゼロに戻す
u_snap(isnan(u_snap)) = 0;
v_snap(isnan(v_snap)) = 0;
p_snap(isnan(p_snap)) = 0;

% POD開始・終了タイムステップの設定
loop_in = loop / 2 ;% 何反復目からPOD解析を開始するか。安定点以上に設定する。
loop_end = loop;
loop_diff = loop_end - loop_in ; % 最終反復数を修正

% 配列の確保
X = zeros((nx + 2) * (ny + 2) * 2, loop_diff); % 流速ベクトル
Xsum = zeros((nx + 2) * (ny + 2) * 2, 1);
u_snap = u_snap(:, :, loop_in : loop_end);
v_snap = v_snap(:, :, loop_in : loop_end);
p_snap = p_snap(:, :, loop_in : loop_end);

% 流速マトリクスの構築
for  ita = 1 : loop_diff
    
    Xu = reshape(u_snap(:, :, ita), [], 1);
    Xv = reshape(v_snap(:, :, ita), [], 1);
    X(:, ita) = vertcat(Xu, Xv);% XuとXvを結合。流速ベクトルを並び立てたマトリクスを構築。
    Xsum = Xsum + X(:, ita);%　平均流速ベクトルのための準備。
    
end

% 平均流速の計算
Xave = Xsum ./ loop_diff;
Xave_u = Xave(1 : (nx + 2) * (ny + 2), 1);
Xave_v = Xave((nx + 2) * (ny + 2) + 1 : 2 * (nx + 2) * (ny + 2), 1);
Xave_u2d = reshape(Xave_u, (nx + 2), (ny + 2));
Xave_v2d = reshape(Xave_v, (nx + 2), (ny + 2));

% 変動場の計算
% for  ita = 1 : loop_diff
%
%     X(:, ita) = X(:, ita) - Xave;
%
% end

% 対角化
ne = 4;% 何番目の固有値まで計算するか
M = transpose(X) * X;
[V, lambda] = eigs(M, ne);% 固有値が大きい順にne個の固有ベクトルを求める。
P = X * V / sqrt(lambda);% POD基底の計算

% 直交性の確認
P_in = 0;
for i = 1 : ne
    for j = 1 : ne
        
        % 同じモードの内積は避ける
        if i == j
            break;
        end
        
        P_in = P_in + dot(P(:, i),P(:, j));%P_inがゼロに近ければOK
        
    end
end

% POD基底を1次元から2次元に修正
Pu1d = zeros((nx + 2) * (ny + 2), ne);% 1次元配列の基底を格納する2次元配列
Pv1d = zeros((nx + 2) * (ny + 2), ne);% 1次元配列の基底を格納する2次元配列
Pu2d = zeros(nx + 2, ny + 2, ne);% 2次元配列の基底を格納する3次元配列
Pv2d = zeros(nx + 2, ny + 2, ne);% 2次元配列の基底を格納する3次元配列

% 各モードの分析・可視化
a = zeros(ne, loop_diff);
lambda_vec = zeros(ne, 1);
lamda_nolm = 0;
for i = 1 : ne
    
    % 固有モードの抽出・整形
    Pu1d(:, i) = P(1 : (nx + 2) * (ny + 2), i);% 基底のu部分のみ取り出す
    Pv1d(:, i) = P((nx + 2) * (ny + 2) + 1 : 2 * (nx + 2) * (ny + 2), i);% 基底のv部分のみ取り出す
    Pu2d(:, :, i) = reshape(P(1 : (nx + 2) * (ny + 2), i), nx + 2, ny + 2);% POD基底の二次元化
    Pv2d(:, :, i) = reshape(P((nx + 2) * (ny + 2) + 1 : 2 * (nx + 2) * (ny + 2), i), nx + 2, ny + 2);% POD基底の二次元化
    
    % 展開係数の計算
    for j = 1 : loop_diff
        a(i, j) = dot((X(:, j)), P(:, i));
    end
    
    % モードエネルギーの計算
    lambda_vec(i) = lambda(i, i) / trace(lambda);% traceは対角項の和。規格化定数の計算。
    
    % 可視化
    vis_contour('U ', 1, i, Pu2d(:, :, i));
    vis_contour('V ', 2, i, Pv2d(:, :, i));
    vis_a('a(t) mode', 3, i, a, loop_diff);
    
end

% モードエネルギーの可視化
vis_ModeEnergy('ModeEnergy.png', 4, lambda_vec);

%% 以下関数

function[] = vis_contour(filename, fignum, mode_num, Pu2d)

figure(fignum);
Pu2d = flipud(rot90(Pu2d));
imagesc(Pu2d);
view(0, 270);%視点の設定
title([filename, 'mode', num2str(mode_num)])
set(gca, 'FontName', 'Times New Roman', 'FontSize', 16);
axis equal; axis tight; axis on;
colorbar('southoutside')
saveas(gcf,[filename, 'mode', num2str(mode_num),'.png'])

end

% 展開係数の可視化
function[] = vis_a(filename, fignum, mode_num, a, loop_diff)

% グローバル変数呼び出し
global dt

tmax = dt * loop_diff;
T = dt : dt : tmax;

figure(fignum)
set(gcf,'visible','off');%グラフ表示しない。保存だけにする。
plot(T, a(mode_num,:))
title(['a(t) mode', num2str(mode_num)])
xlabel('time (s)')
legend('{\sl a}({\sl t} )', '{\sl true a}({\sl t} )')
set( gca, 'FontName', 'Times New Roman', 'FontSize', 16 );
saveas(gcf,[filename, num2str(mode_num), '.png'])

end

function[] = vis_ModeEnergy(filename, fignum, lambda_vec)

% グローバル変数呼び出し
global ne

figure(fignum)
set(gcf,'visible','off');%グラフ表示しない。保存だけにする。
semilogy(1 : ne, lambda_vec, '-o')%対数グラフで作成
title('mode energy')
xlabel('mode')
ylabel('nomalized \lambda')
set( gca, 'FontName', 'Times New Roman', 'FontSize', 16 );
saveas(gcf,filename)

end
