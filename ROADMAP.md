
SIFT - Outstanding choice:
-----

Gaussian pyramid: A[16,25] * B[25,360000] → separable 5x5 filters across 800×600

DoG computation: element-wise but can batch A[8,360000] * B[360000,1]

Keypoint descriptor: A[16,16] * B[16,16] → 4×4 histogram accumulation per keypoint

Orientation histogram: A[36,256] * B[256,N_keypoints] → weighted binning

HOG - Very good:
-----

Gradient: A[3,9] * B[9,360000] → 3×3 Sobel across all pixels

Cell histograms: A[9,64] * B[64,9375] → 9-bin histograms for 7500 8×8 cells

Block normalization: A[36,36] * B[36,1875] → 2×2 cell blocks, L2 norm

Stereo depth - Excellent:
-----

Cost volume: A[64,64] * B[64,360000×D] → NCC templates, D≈128 disparities

SGM aggregation: A[8,360000] * B[360000,128] → 8-direction path costs

Sub-pixel refinement: A[3,3] * B[3,N_pixels] → quadratic interpolation

Wavelet transform - Good:
-----

2D DWT level 1: A[4,4] * B[4,90000] → 2×2 lifting on 300×300 subbands

Multi-level: A[4,4] * B[4,22500] → recursive on 150×150, etc.

Medium MMA utility:
-----

K-means: A[K,3] * B[3,360000] → K≈16 centroids, RGB distance computation

Morphological: A[25,25] * B[25,360000] → 5×5 structuring elements

Key insight: SIFT gives you the richest MMA variety - from small dense ops (16×16 descriptors) to large sparse ones (filter application), plus interesting intermediate sizes for multi-scale processing.

Utility breakdown in the ViT era:
=====

Still highly relevant:
-----

Stereo depth: CNNs/ViTs struggle with geometric constraints; classical stereo + deep refinement is common. MiDaS, DPT still use depth priors.

Morphological ops: Essential preprocessing for segmentation, medical imaging, industrial vision. No learning replacement.

Wavelet transforms: Critical for compression (JPEG2000), denoising, medical imaging. Domain-specific, irreplaceable.

Niche but valuable:
-----

HOG: Still used in embedded systems, real-time applications where ViT is too heavy. Good for understanding gradient-based features that ViTs learn implicitly.

K-means quantization: Useful for ViT preprocessing, color space analysis, compression pipelines.

Mostly historical/educational:
-----

SIFT/ORB: Replaced by learned features (SuperPoint, D2-Net), but excellent for understanding what ViTs learn to approximate. Still used in SLAM when you need explicit correspondences.

Log-polar: Mostly research curiosity, though some bio-inspired vision work.

Conclusion:
=====


Modern context: ViTs learn feature hierarchies that subsume HOG/SIFT, but the geometric operations (stereo, morphology, wavelets) remain essential. The classical methods are now often "differentiable modules" in end-to-end pipelines.

For GPU learning: These are perfect because they teach fundamental parallel patterns that apply to ViT building blocks - matrix multiply, reduction, memory hierarchy optimization. Understanding HOG gradients helps you optimize ViT attention computations.

Recommendation: Stereo depth for maximum modern relevance + rich MMA patterns.

HOG is closest to ViT by far.

Key parallels:

Patch-based processing:

HOG: 8×8 cells → feature vectors

ViT: 16×16 patches → token embeddings

Spatial feature aggregation:

HOG: 2×2 cell blocks with overlapping windows

ViT: Self-attention across spatial positions

Gradient-based features:

HOG: Explicit gradient orientation histograms (9 bins)

ViT: Learns gradient-like edge detectors in early layers

Multi-scale implicit handling:

HOG: Block normalization provides translation/illumination invariance

ViT: Attention mechanism learns spatial relationships

Concrete similarity: HOG's 9-bin orientation histogram is essentially a learned basis - ViTs learn similar edge/orientation detectors but with ~512-1024 dimensions instead of 9.

Modern insight: You can think of ViT as "learnable HOG" - instead of fixed gradient orientations, it learns optimal feature bases. The attention mechanism replaces HOG's rigid block structure with flexible spatial aggregation.
